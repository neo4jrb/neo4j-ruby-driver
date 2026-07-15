# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents the result of running a Cypher statement.
    #
    # Records arrive through a Bolt::RecordBuffer that the connection's dedicated
    # reader fills (via the StreamHandler the RUN's PULL registered). The cursor
    # shifts from that buffer and, as it drains past the low watermark, issues the
    # next PULL — so the reader keeps a batch or two ahead (watermark prefetch).
    # The terminal SUCCESS's metadata becomes the Summary; a stream FAILURE is
    # re-raised (classified) on the next read.
    class Result
      include Enumerable

      def initialize(connection, keys = [], buffer:, handler:, query_text: nil, parameters: {},
                     run_metadata: {}, fetch_size: 1000, qid: nil, terminated_error: nil,
                     on_summary: nil, on_release: nil)
        @connection = connection
        @keys = keys
        @buffer = buffer          # Bolt::RecordBuffer, filled by the reader
        @handler = handler        # the StreamHandler registered for this result's PULLs
        @query_text = query_text
        @parameters = parameters
        @run_metadata = run_metadata
        @fetch_size = fetch_size
        # Bolt query id (explicit-tx RUN reply). A PULL/DISCARD targets the *last*
        # opened query when qid is omitted, so we only send it once this result is
        # no longer the transaction's current one — see #demote! and #request_more.
        @qid = qid
        @demoted = false
        # Callable returning the error that terminated the owning transaction
        # (a failure in a *sibling* result or a tx method), or nil. Once set,
        # this result must raise it on access rather than pull — a terminated tx
        # leaves the connection FAILED, so more wire traffic is invalid. nil for
        # auto-commit results (no enclosing transaction).
        @terminated_error = terminated_error
        @failure = nil    # this result's own classified stream failure, if any
        @on_summary = on_summary  # called with the built Summary when the stream ends in SUCCESS
        @on_release = on_release  # called once when the connection is no longer needed
        @records = []       # records pulled into memory by #buffer (not by iteration)
        @had_record = false # any RECORD arrived on this stream — drives the GQL outcome status
        @summary = nil
        @consumed = false   # stream fully drained (terminal seen)
        @discarded = false  # records explicitly released; further access raises
        @failed = false     # stream ended with a server FAILURE; connection needs RESET
        @cancelling = false # consume(): abandon the rest — DISCARD the next batch instead of PULL
        @peeked_record = nil
      end

      attr_reader :connection, :keys

      def has_next?
        raise Exceptions::ResultConsumedException if @discarded
        return true if @records.any?
        return true if @peeked_record
        return false if @consumed

        @peeked_record = next_record
        !@peeked_record.nil?
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
        # Abandon the rest: the watermark path (request_more) now DISCARDs instead
        # of PULLing the next batch, so the server stops shipping records and the
        # stream ends on its terminating SUCCESS. We must still drain the records
        # already in flight (dropping them) so the connection is left clean.
        @cancelling = true
        begin
          nil while next_record unless @consumed
        ensure
          @records.clear
          @discarded = true
        end

        @summary
      end

      # Pull all remaining records into memory so the underlying connection can be
      # reused for another query. Unlike #consume, records stay accessible.
      def buffer
        return if @consumed

        if @peeked_record
          @records << @peeked_record
          @peeked_record = nil
        end

        while (record = next_record)
          @records << record
        end
      end

      def none?
        !has_next?
      end

      def failed?
        @failed
      end

      # This result's own classified stream failure (nil unless it failed). The
      # transaction reads it to surface the terminating error to sibling results.
      attr_reader :failure

      # A later RUN in the same transaction made another query current; from now
      # on this result's PULL/DISCARD must name its qid explicitly (see
      # #request_more). Called by Transaction#run when it opens the next result.
      def demote! = @demoted = true

      # Mark this result as released without touching the wire — the connection is
      # being returned/reset by the caller. Callers drain (consume/buffer) or RESET
      # before this, so the stream is already finished; further access raises.
      def discard!
        @peeked_record = nil
        @discarded = true
        release_connection
      end

      private

      # Next record from the buffer (reader-filled), or nil at end of stream.
      # Records arrive incrementally, so take one the moment it's buffered and
      # prefetch (request_more) once we drain past the low watermark. When the
      # buffer is momentarily empty but the stream is still open, issue any due
      # PULL then #await — a single wait that wakes on the next record (mid-batch)
      # or the batch promise resolving (batch-end, so we PULL the next batch
      # rather than block forever). A stream FAILURE surfaces as a raise from
      # try_shift — classified (routing's ServiceUnavailable→SessionExpired etc.)
      # and marked @failed so the caller RESETs.
      def next_record
        raise_if_terminated
        loop do
          record = take_from_buffer
          case record
          when :empty
            request_more
            @buffer.await
          when :ended
            finalize_stream
            return nil
          else
            request_more
            return build_record(record)
          end
        end
      end

      # try_shift, but turn a stream failure into the classified exception and
      # finalize a summary from run metadata so a later #consume still returns it
      # (matches main's on_failure, which finalized on the failure).
      def take_from_buffer
        @buffer.try_shift
      rescue StandardError => e
        @failed = true
        @consumed = true
        finalize({})
        raise(@failure = @connection.classify_failure(e))
      end

      # A sibling result or a tx method failed, terminating the transaction: the
      # connection is now FAILED, so raise that error instead of pulling. Our own
      # failure (@failed) surfaces through take_from_buffer, not here.
      def raise_if_terminated
        return if @failed

        error = @terminated_error&.call
        raise error if error
      end

      # Watermark autopull: once the buffer has drained to/below the low watermark
      # and the server has confirmed (via a completed batch) it has more, request
      # the next batch — PULL normally, or DISCARD once consume() has cancelled
      # (abandon the rest). Driving DISCARD through the same gate is what avoids a
      # premature DISCARD before the in-flight PULL's reply has even arrived.
      def request_more
        return unless @buffer.pull_ready?

        @buffer.note_pull_issued
        # Omit qid while this is the transaction's current query (the server
        # defaults to the last opened one); include it explicitly once a later
        # RUN has demoted us, so the pull still targets *this* stream. Auto-commit
        # and single-result transactions never demote, so they keep sending the
        # bare {n} the stub scripts expect (qid is optional there).
        extra = @demoted && @qid ? { qid: @qid } : {}
        message = @cancelling ? @connection.protocol.build_discard(extra) : @connection.protocol.build_pull(extra.merge(n: @fetch_size))
        @connection.send_message(message, @handler)
        @connection.flush
      end

      # End of stream: a terminating SUCCESS carries summary metadata (build the
      # Summary, harvest the bookmark); a bare finish (IGNORED) carries none.
      def finalize_stream
        if (metadata = @buffer.summary)
          finalize(metadata)
          @on_summary&.call(@summary)
        else
          @consumed = true
        end
        release_connection
      end

      def build_record(msg)
        @had_record = true
        Record.new(@keys, msg.fields)
      end

      def finalize(metadata)
        @summary = Summary::ResultSummary.new(@run_metadata.merge(metadata), @query_text, @parameters, @connection,
                                              had_record: @had_record)
        @consumed = true
      end

      def release_connection
        @on_release&.call
        @on_release = nil # idempotent
      end
    end
  end
end
