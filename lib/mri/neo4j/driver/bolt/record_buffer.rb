# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Bounded record buffer for one streaming result, with a high/low watermark
      # autopull policy. Sits between the connection's reader (producer) and the
      # cursor (consumer) and owns the two kinds of backpressure
      # (docs/unified-pipeline.md):
      #
      #   * **Driver → consumer** — the `SizedQueue` bound. The reader blocks in
      #     `push_record` when the buffer is full; the bound *is* the backpressure.
      #   * **Server → driver** — Bolt flow control. The cursor checks
      #     `pull_ready?` as it drains and, when the buffer has fallen to/below the
      #     low watermark and the server has said `has_more`, issues the next
      #     `PULL {n: fetch_size}` (marking it via `note_pull_issued`). Hysteresis
      #     (high ≈ 2× fetch_size, low a fraction) keeps PULLs from thrashing.
      #
      # All sync primitives are stdlib + scheduler-aware, so a consumer running as
      # a fiber under a host reactor yields rather than blocking the thread.
      class RecordBuffer
        attr_reader :fetch_size, :high_watermark, :low_watermark

        def initialize(fetch_size:, high_watermark: nil, low_watermark: nil)
          @fetch_size = fetch_size
          # Defaults: hold ~2 batches, refill under half a batch. fetch_size -1
          # ("pull all in one batch") never paginates, so just size the bound for
          # a steady single-batch handoff.
          @high_watermark = high_watermark || (fetch_size.positive? ? fetch_size * 2 : 1000)
          @low_watermark = low_watermark || [@high_watermark / 2, 1].max
          # The bound is the driver→consumer backpressure: the reader blocks here
          # when the consumer is slow. Floor at 1 (SizedQueue requires > 0).
          @queue = Thread::SizedQueue.new([@high_watermark, 1].max)
          @mutex = Mutex.new
          @has_more = true        # server may have more records for this stream
          @pull_in_flight = true  # the first PULL is pipelined with RUN by the cursor
          @ended = false          # final SUCCESS/IGNORED seen → no more records
          @error = nil            # stream failed; re-raised to the consumer
          @summary = nil          # terminating SUCCESS metadata
        end

        # --- Producer (reader) side -----------------------------------------

        # Add a decoded record. Blocks (yields under a scheduler) when the buffer
        # is at its bound — that block is the consumer backpressure.
        def push_record(record)
          @queue.push(record)
        end

        # The current batch's PULL reply arrived; `has_more` says whether to keep
        # paging. Either way a PULL is no longer in flight, so the cursor may
        # issue the next one once it drains past the low watermark.
        def batch_complete(has_more:)
          @mutex.synchronize { @has_more = has_more; @pull_in_flight = false }
        end

        # The stream is fully drained (final SUCCESS / IGNORED). Stash the summary
        # and close the queue so a consumer parked in shift wakes with nil.
        def finish(summary = nil)
          @mutex.synchronize { @summary = summary; @ended = true; @has_more = false }
          @queue.close
        end

        # The stream failed; the consumer re-raises this on its next shift.
        def fail(error)
          @mutex.synchronize { @error ||= error; @ended = true; @has_more = false }
          @queue.close
        end

        # The terminating SUCCESS's metadata (nil until finished / on failure).
        def summary = @mutex.synchronize { @summary }

        # --- Consumer (cursor) side -----------------------------------------

        # Next record, or nil when the stream is exhausted. Blocks (yields under a
        # scheduler) until a record arrives or the stream ends. Re-raises a
        # stream failure.
        def shift
          record = @queue.pop # nil once closed and drained
          raise @error if record.nil? && @error

          record
        end

        def empty? = @queue.empty?
        def size = @queue.size
        def ended? = @mutex.synchronize { @ended }
        def has_more? = @mutex.synchronize { @has_more }

        # --- Autopull policy (cursor side) ----------------------------------

        # True when the cursor should issue the next PULL: the server has more,
        # none is in flight, and the buffer has drained to/below the low watermark.
        def pull_ready? = @mutex.synchronize { @has_more && !@pull_in_flight && @queue.size <= @low_watermark }

        # The cursor issued the next PULL; don't issue another until it completes.
        def note_pull_issued = @mutex.synchronize { @pull_in_flight = true }
      end
    end
  end
end
