# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents the result of running a Cypher statement.
    #
    # Acts as a visitor for the streaming Bolt responses (Record/Success/
    # Failure/Ignored): each fetched response calls back into one of the
    # `on_*` methods below. The three drain modes (peek for #has_next?,
    # discard for #consume, store for #buffer) install a per-call
    # `@record_handler` so the polymorphic dispatch sees uniform
    # behaviour for SUCCESS/FAILURE while record handling stays
    # context-specific.
    class Result
      include Enumerable

      def initialize(connection, keys = [], query_text: nil, parameters: {}, run_metadata: {},
                     fetch_size: 1000, on_summary: nil, on_release: nil)
        @connection = connection
        @keys = keys
        @query_text = query_text
        @parameters = parameters
        @run_metadata = run_metadata
        @fetch_size = fetch_size  # used when SUCCESS carries has_more=true to request the next batch
        @on_summary = on_summary  # called with the built Summary when stream ends in SUCCESS
        @on_release = on_release  # called once when the connection is no longer needed
        @records = []       # records pulled into memory by #buffer (not by iteration)
        @summary = nil
        @consumed = false   # stream has been fully drained from the wire
        @discarded = false  # records were explicitly released; further access raises
        @failed = false     # stream ended with a server FAILURE; connection needs RESET
        @cancelled = false  # consume() called mid-stream — server should DISCARD, not paginate
        @peeked_record = nil
      end

      attr_reader :connection, :keys

      def has_next?
        raise Exceptions::ResultConsumedException if @discarded
        return true if @records.any?
        return false if @consumed
        return true if @peeked_record

        # Loop until the stream gives us a RECORD or signals end. A
        # SUCCESS in the middle (has_more=true) triggers another PULL
        # in on_success, so the next iteration's fetch_response reads
        # the first record of the new batch.
        with_record_handler(->(msg) { @peeked_record = build_record(msg) }) do
          @connection.fetch_response.accept(self) until @consumed || @peeked_record
        end
        !@peeked_record.nil?
      rescue StandardError
        @consumed = true
        raise
      end

      def next
        raise Exceptions::ResultConsumedException if @discarded
        return @records.shift if @records.any?
        raise Exceptions::NoSuchRecordException, 'No more records' unless has_next?

        record = @peeked_record
        @peeked_record = nil
        record
      end

      def peek
        raise Exceptions::ResultConsumedException if @discarded
        return @records.first if @records.any?
        raise Exceptions::NoSuchRecordException, 'No more records' unless has_next?

        @peeked_record
      end

      def single
        raise Exceptions::ResultConsumedException if @discarded

        unless has_next?
          raise Exceptions::NoSuchRecordException,
                'Cannot retrieve a single record, because this result is empty.'
        end

        record = self.next

        if has_next?
          raise Exceptions::NoSuchRecordException,
                'Expected a result with a single record, but this result contains at least one more. ' \
                'Ensure your query returns only one record.'
        end

        record
      end

      def each(&block)
        raise Exceptions::ResultConsumedException if @discarded
        return to_enum(:each) unless block_given?

        block.call(self.next) while has_next?
      end

      def to_a
        raise Exceptions::ResultConsumedException if @discarded

        records = []
        records << self.next while has_next?
        records
      end

      def consume
        return @summary if @discarded

        @peeked_record = nil
        # Set the cancel flag before draining so on_success swaps the
        # next pagination step from PULL to DISCARD — the server then
        # abandons remaining records and replies with the final summary
        # SUCCESS, instead of streaming every record into the void.
        @cancelled = true
        begin
          drain_until_consumed { |_msg| } unless @consumed
        ensure
          @records.clear
          @discarded = true
        end

        @summary
      end

      # Pull all remaining records into memory so the underlying connection
      # can be reused for another query. Unlike #consume, records stay
      # accessible via #each/#to_a/etc.
      def buffer
        return if @consumed

        if @peeked_record
          @records << @peeked_record
          @peeked_record = nil
        end

        drain_until_consumed { |msg| @records << build_record(msg) }
      end

      def none?
        !has_next?
      end

      def failed?
        @failed
      end

      # Mark this result as released without touching the wire. Used by the
      # session when closing — the underlying connection is gone, so further
      # record access is impossible and must raise ResultConsumedException.
      def discard!
        @peeked_record = nil
        @discarded = true
        release_connection
      end

      # --- Visitor callbacks (Bolt::Message#accept dispatches here) -------

      def on_record(msg)
        @record_handler&.call(msg)
      end

      def on_success(msg)
        # has_more=true means the server still has records beyond the
        # last PULL's batch limit. Either pull the next batch or, if
        # consume() asked to cancel the stream, send DISCARD instead so
        # the server stops shipping records and returns the summary.
        if msg.metadata[:has_more]
          next_msg = @cancelled ? Bolt::Message.discard(n: -1) : Bolt::Message.pull(n: @fetch_size)
          @connection.send_message(next_msg)
          @connection.flush
          return
        end

        finalize(msg.metadata)
        @on_summary&.call(@summary)
        # Stream is done — auto-commit results don't need the connection
        # past SUCCESS. Records previously buffered remain accessible.
        release_connection
      end

      def on_failure(msg)
        finalize(msg.metadata)
        @failed = true
        # Connection is in FAILED state; the caller (Session) will RESET
        # before releasing. We just mark failed; the caller path drives
        # the release via #discard!.
        #
        # For routed connections, thread the failure through the
        # classifier so DatabaseUnavailable / NotALeader on a mid-stream
        # PULL still trigger deactivate / on_write_failure. The classify
        # returns the (possibly swapped) exception to raise.
        raise @connection.classify_failure(msg.to_exception)
      end

      def on_ignored(_msg)
        # Treated as terminal — the prior request in the batch already failed.
        @consumed = true
        release_connection
      end

      private

      def drain_until_consumed(&record_handler)
        with_record_handler(record_handler) do
          @connection.fetch_response.accept(self) until @consumed
        end
      end

      def with_record_handler(handler)
        previous = @record_handler
        @record_handler = handler
        yield
      ensure
        @record_handler = previous
      end

      def build_record(msg)
        Record.new(@keys, msg.fields)
      end

      def finalize(metadata)
        @summary = Summary::ResultSummary.new(@run_metadata.merge(metadata), @query_text, @parameters, @connection)
        @consumed = true
      end

      def release_connection
        @on_release&.call
        @on_release = nil  # idempotent
      end
    end
  end
end
