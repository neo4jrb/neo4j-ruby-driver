# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Bounded record buffer for one streaming result, with high/low watermark
      # autopull policy. Sits between the pump (producer) and the cursor
      # (consumer) and owns the two distinct kinds of backpressure (see
      # docs/sans-io-pump.md):
      #
      #   * **Driver → consumer** — the `SizedQueue` bound. The pump blocks on
      #     `push_record` when the buffer is full; the bound *is* the backpressure.
      #   * **Server → driver** — Bolt flow control. `needs_pull?` gates the next
      #     `PULL {n: fetch_size}`: request more only once the buffer drains below
      #     the low watermark and the server has said `has_more`. Hysteresis (high
      #     ≈ 1–2× fetch_size, low a fraction) keeps PULLs from thrashing — the
      #     batch is the natural granularity since the server can't be stopped
      #     mid-batch.
      #
      # All sync primitives are stdlib + scheduler-aware, so a consumer or pump
      # running as a fiber under a host reactor yields rather than blocking the
      # thread — no `async` dependency.
      class RecordBuffer
        attr_reader :fetch_size, :high_watermark, :low_watermark

        def initialize(fetch_size:, high_watermark: nil, low_watermark: nil)
          @fetch_size = fetch_size
          # Defaults: hold up to ~2 batches, refill when under half a batch.
          @high_watermark = high_watermark || fetch_size * 2
          @low_watermark = low_watermark || [fetch_size / 2, 1].max
          # The bound is the driver→consumer backpressure: the pump blocks here
          # when the consumer is slow. Floor at 1 (SizedQueue requires > 0).
          @queue = Thread::SizedQueue.new([@high_watermark, 1].max)
          @mutex = Mutex.new
          # Signalled when the consumer pops or a batch completes, so a pump
          # parked in await_pull_capacity wakes to re-check. Scheduler-aware
          # (stdlib CV), so a pump fiber yields rather than blocking the thread.
          @drain = ConditionVariable.new
          @has_more = true       # server may have more records for this stream
          @pull_in_flight = false # a PULL has been issued, reply not yet seen
          @ended = false         # final SUCCESS consumed → no more records
          @error = nil           # stream failed; re-raised to the consumer
          @summary = nil         # terminating SUCCESS metadata
        end

        # --- Producer (pump) side -------------------------------------------

        # Add a decoded record. Blocks (yields under a scheduler) when the
        # buffer is at its bound — that block is the consumer backpressure.
        def push_record(record)
          @queue.push(record)
        end

        # The current batch's PULL reply arrived. `has_more` tells us whether to
        # keep paging; either way a PULL is no longer in flight. Wake the pump so
        # it can decide on the next batch.
        def batch_complete(has_more:)
          @mutex.synchronize do
            @has_more = has_more
            @pull_in_flight = false
            @drain.broadcast
          end
        end

        # The stream is fully drained (final SUCCESS, no has_more). Stash the
        # summary metadata for the consumer, unblock a consumer waiting on an
        # empty buffer, and wake any parked pump.
        def finish(summary = nil)
          @mutex.synchronize { @summary = summary; @ended = true; @has_more = false; @drain.broadcast }
          @queue.close
        end

        # The terminating SUCCESS's metadata (nil until finished / on failure).
        def summary = @mutex.synchronize { @summary }

        # The stream failed; the consumer re-raises this on its next read.
        def fail(error)
          @mutex.synchronize { @error ||= error; @ended = true; @has_more = false; @drain.broadcast }
          @queue.close
        end

        # --- Consumer (cursor) side -----------------------------------------

        # Next record, or nil when the stream is exhausted. Blocks (yields under
        # a scheduler) until a record arrives or the stream ends. Re-raises a
        # stream failure.
        def shift
          record = @queue.pop # nil once closed and drained
          # A slot freed: maybe we've crossed below the low watermark, so wake a
          # pump parked waiting to issue the next PULL.
          @mutex.synchronize { @drain.broadcast }
          raise @error if record.nil? && @error

          record
        end

        def empty? = @queue.empty?
        def size = @queue.size
        def ended? = @mutex.synchronize { @ended }

        # --- Autopull policy (pump side) ------------------------------------

        # Block until the pump should issue the next PULL — the server has more,
        # none is in flight, and the buffer has drained to/below the low
        # watermark (hysteresis: don't refill on every freed slot, refill a
        # batch at a time). Returns true and marks a PULL in flight, or false
        # when the stream has ended/failed/been cancelled (pump should stop).
        # Scheduler-aware wait, so a pump fiber yields to the host reactor.
        def await_pull_capacity
          @mutex.synchronize do
            @drain.wait(@mutex) until @ended || @error || ready_to_pull?
            return false if @ended || @error

            @pull_in_flight = true
            true
          end
        end

        # Locked snapshot for introspection/tests (no blocking).
        def pull_ready? = @mutex.synchronize { ready_to_pull? }

        private

        def ready_to_pull?
          @has_more && !@pull_in_flight && @queue.size <= @low_watermark
        end
      end
    end
  end
end
