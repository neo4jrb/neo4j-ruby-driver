# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Record buffer for one streaming result, with a high/low watermark autopull
      # policy. Sits between the connection's reader (producer) and the cursor
      # (consumer), and unifies two things under one mutex + condition variable:
      # the record queue *and* the batch's "has_more promise".
      #
      # Records are delivered incrementally — pushed the instant the reader decodes
      # them — so the cursor sees record 1 without waiting for the whole batch. The
      # batch's terminating SUCCESS resolves the promise (`batch_complete`), which
      # says whether the server has more. The cursor drives flow control:
      #
      #   * after each record, once drained to/below the low watermark, it checks
      #     the promise (`pull_ready?`, non-blocking) and, if fulfilled with
      #     has_more, issues the next `PULL {n: fetch_size}` — prefetch overlap;
      #   * when it drains the buffer empty mid-stream, it `await`s — one wait that
      #     wakes on *either* the next record *or* the promise resolving. That
      #     shared wait is the crux: mid-batch it wakes on a record (incremental
      #     delivery preserved), at batch-end it wakes on the promise (so it PULLs
      #     the next batch instead of blocking forever on a record that, the SUCCESS
      #     having no payload, will never come).
      #
      # The cursor is the sole writer (issues every PULL/DISCARD); the reader only
      # ever fills. All sync primitives are stdlib + scheduler-aware, so a cursor
      # running as a fiber under a host reactor yields rather than blocking the
      # thread. See docs/unified-pipeline.md.
      class RecordBuffer
        attr_reader :fetch_size, :high_watermark, :low_watermark

        def initialize(fetch_size:, high_watermark: nil, low_watermark: nil)
          @fetch_size = fetch_size
          # Defaults: refill under half of ~2 batches held. fetch_size -1 ("pull
          # all in one batch") never paginates, so just size the watermarks for a
          # steady single-batch handoff.
          @high_watermark = high_watermark || (fetch_size.positive? ? fetch_size * 2 : 1000)
          @low_watermark = low_watermark || [@high_watermark / 2, 1].max
          @mutex = Mutex.new
          @cv = ConditionVariable.new
          @records = []           # incrementally filled by the reader, drained by the cursor
          @has_more = true        # server may have more records for this stream
          @pull_in_flight = true  # the first PULL is pipelined with RUN — promise unfulfilled
          @ended = false          # terminal SUCCESS/IGNORED seen → no more records
          @error = nil            # stream failed; re-raised to the cursor after buffered records
          @summary = nil          # terminating SUCCESS metadata
        end

        # --- Producer (reader) side -----------------------------------------

        # Append a decoded record and wake a cursor parked in #await. Never blocks
        # (unbounded); the cursor's watermark bounds how much the server ships.
        def push_record(record)
          @mutex.synchronize { @records.push(record); @cv.broadcast }
        end

        # The current batch's terminal SUCCESS arrived — resolve the promise.
        # `has_more` says whether to keep paging; either way no PULL is in flight,
        # so the cursor may issue the next once it drains past the low watermark.
        # Wake a cursor parked in #await waiting for exactly this.
        def batch_complete(has_more:)
          @mutex.synchronize { @has_more = has_more; @pull_in_flight = false; @cv.broadcast }
        end

        # Final batch (terminating SUCCESS without has_more, or IGNORED): stash the
        # summary, mark ended, and wake the cursor.
        def finish(summary = nil)
          @mutex.synchronize do
            @summary = summary
            @ended = true
            @has_more = false
            @pull_in_flight = false
            @cv.broadcast
          end
        end

        # The stream failed: arm the error the cursor re-raises *after* it drains
        # the records already delivered (records that preceded the failure are
        # valid), and wake it.
        def fail(error)
          @mutex.synchronize do
            @error ||= error
            @ended = true
            @has_more = false
            @pull_in_flight = false
            @cv.broadcast
          end
        end

        # The terminating SUCCESS's metadata (nil until finished / on failure).
        def summary = @mutex.synchronize { @summary }

        # --- Consumer (cursor) side -----------------------------------------

        # Non-blocking: the next buffered record, or :empty when none is buffered
        # yet, or :ended once the stream is drained and terminal. Buffered records
        # are handed out before a stream failure is raised (they preceded it).
        def try_shift
          @mutex.synchronize do
            return @records.shift unless @records.empty?
            raise @error if @error

            @ended ? :ended : :empty
          end
        end

        # Block (colorlessly) until there's something to re-evaluate: a record was
        # delivered, the batch completed (promise resolved), or the stream
        # ended/failed. Called only when the cursor has drained the buffer empty
        # and a PULL is still outstanding (records coming, or its SUCCESS pending).
        def await
          @mutex.synchronize do
            @cv.wait(@mutex) while @records.empty? && !@ended && @error.nil? && @pull_in_flight
          end
        end

        def empty? = @mutex.synchronize { @records.empty? }
        def size = @mutex.synchronize { @records.size }
        def ended? = @mutex.synchronize { @ended }
        def has_more? = @mutex.synchronize { @has_more }

        # --- Autopull policy (cursor side) ----------------------------------

        # True when the cursor should issue the next PULL: the batch promise is
        # fulfilled (none in flight) with has_more, and the buffer has drained
        # to/below the low watermark.
        def pull_ready? = @mutex.synchronize { @has_more && !@pull_in_flight && @records.size <= @low_watermark }

        # The cursor issued the next PULL — the promise is unfulfilled again; don't
        # issue another until this batch completes.
        def note_pull_issued = @mutex.synchronize { @pull_in_flight = true }
      end
    end
  end
end
