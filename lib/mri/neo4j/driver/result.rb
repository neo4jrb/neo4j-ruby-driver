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
        # Prefetch promotion (set once the first batch reports has_more): a
        # background pump drains batches 2..N off the connection into @buffer
        # while the consumer processes the current batch. Single-batch results
        # never promote — their lone PULL is already pipelined with RUN, so the
        # synchronous path below is optimal and spawns nothing. See
        # docs/sans-io-pump.md and Bolt::Pump.
        @promoted = false
        @buffer = nil       # Bolt::RecordBuffer once promoted
        @pump = nil         # Bolt::Pump driving the connection
        @pump_handle = nil  # Executor handle (Thread/Fiber) — joined before release
      end

      attr_reader :connection, :keys

      def has_next?
        raise Exceptions::ResultConsumedException if @discarded
        return true if @records.any?
        return false if @consumed
        return true if @peeked_record

        if @promoted
          # Records now arrive from the background pump via the buffer.
          @peeked_record = next_buffered_record
        else
          # Loop until the stream gives us a RECORD or signals end. A SUCCESS
          # in the middle (has_more=true) either triggers another PULL in
          # on_success (single batch so far) or *promotes* to the prefetch
          # pump — in which case the loop exits and the first post-promotion
          # record comes from the buffer.
          with_record_handler(->(msg) { @peeked_record = build_record(msg) }) do
            @connection.fetch_response.accept(self) until @consumed || @peeked_record || @promoted
          end
          @peeked_record = next_buffered_record if @promoted && @peeked_record.nil? && !@consumed
        end
        !@peeked_record.nil?
      rescue StandardError => e
        @consumed = true
        # A connection failure mid-stream (e.g. the writer dropped during
        # PULL) arrives here, not via on_failure — classify it so routing
        # turns ServiceUnavailable into SessionExpired (no-op for direct).
        raise @connection.classify_failure(e)
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
          if @promoted
            cancel_via_pump unless @consumed
          else
            drain_until_consumed { |_msg| } unless @consumed
          end
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

        if @promoted
          drain_buffer_into_records
        else
          drain_until_consumed { |msg| @records << build_record(msg) }
          # on_success may have promoted mid-drain (first has_more); continue
          # materialising the remaining batches from the buffer.
          drain_buffer_into_records if @promoted && !@consumed
        end
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
        # Stop a still-running pump and wait for it to exit so its thread/fiber
        # can't read the connection after we release it (a reused connection
        # with a stray reader would corrupt the protocol). finish() closes the
        # buffer, waking a pump parked in push_record (ClosedQueueError → clean
        # exit) or await_pull_capacity (ended → stop). Normal paths drain via
        # consume/buffer first, so the pump is already done and this is a no-op.
        if @pump
          @buffer.finish
          @pump_handle&.join
        end
        release_connection
      end

      # --- Visitor callbacks (Bolt::Message#accept dispatches here) -------

      def on_record(msg)
        @record_handler&.call(msg)
      end

      def on_success(msg)
        # Only the *first* batch's terminal reaches here — once promoted the
        # pump is the connection's visitor, not the Result.
        #
        # has_more=true means the server still has records beyond this batch.
        # If the consumer already cancelled (consume() during batch 1), send
        # DISCARD and stay synchronous. Otherwise promote to the prefetch pump,
        # which streams the remaining batches into @buffer in the background.
        if msg.metadata[:has_more]
          if @cancelled
            @connection.send_message(@connection.protocol.build_discard(n: -1))
            @connection.flush
          else
            promote
          end
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

      # First batch reported has_more: hand the remaining batches to a
      # background pump. Send batch 2's PULL on this (consumer) thread — the
      # pump issues every PULL after that — then spawn it. Once spawned the
      # pump is the connection's sole reader/writer; the consumer only ever
      # touches @buffer, so there's no concurrent socket access. The pump runs
      # as a fiber under a host scheduler, else its own thread (Executor).
      def promote
        @buffer = Bolt::RecordBuffer.new(fetch_size: @fetch_size)
        source = Bolt::RecordSource.new(@connection)
        source.pull(@fetch_size)
        @pump = Bolt::Pump.new(source, @buffer)
        @pump_handle = Bolt::Executor.spawn { @pump.run }
        @promoted = true
      end

      # Next record from the prefetch buffer, or nil at end of stream. A nil
      # means the pump saw the terminating SUCCESS: finalize from the buffer's
      # summary, harvest the bookmark, and release the connection — the same
      # terminal handling on_success does for the synchronous path. The pump's
      # thread/fiber has finished by then (it closes the buffer last); join it
      # before release so it can't touch a reused connection. A stream failure
      # surfaces as a raise from shift (handled by the caller's classifier).
      def next_buffered_record
        msg =
          begin
            @buffer.shift
          rescue StandardError
            @failed = true
            raise
          end
        return build_record(msg) if msg

        # End of stream. A terminating SUCCESS carries summary metadata; a bare
        # finish (e.g. IGNORED) carries none — mirror Result#on_ignored and just
        # mark consumed, no summary, like the synchronous path.
        if (summary = @buffer.summary)
          finalize(summary)
          @on_summary&.call(@summary)
        else
          @consumed = true
        end
        @pump_handle&.join
        release_connection
        nil
      end

      # Materialise every remaining buffered record (used by #buffer).
      def drain_buffer_into_records
        while (record = next_buffered_record)
          @records << record
        end
      end

      # Abandon a promoted stream: tell the pump to DISCARD the rest, then drain
      # the buffer (dropping records, which also unblocks a pump parked in
      # push_record) until the server's terminating SUCCESS closes it. Harvest
      # that summary's bookmark — DISCARD still returns one for auto-commit.
      # A failure surfaced during the drain propagates (classified) exactly as
      # the synchronous consume() path does; the connection is then left for the
      # caller to RESET + discard!, not released here.
      def cancel_via_pump
        @pump.cancel
        error = nil
        begin
          nil while @buffer.shift
        rescue StandardError => e
          @failed = true
          error = e
        end
        @pump_handle&.join
        raise @connection.classify_failure(error) if error

        if !@consumed && (summary = @buffer.summary)
          finalize(summary)
          @on_summary&.call(@summary)
        else
          @consumed = true
        end
        release_connection
      end

      def drain_until_consumed(&record_handler)
        with_record_handler(record_handler) do
          # Stop on promotion too: once on_success hands the stream to the pump,
          # the pump is the sole reader — the caller continues from the buffer.
          @connection.fetch_response.accept(self) until @consumed || @promoted
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
