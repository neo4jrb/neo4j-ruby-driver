# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Record buffer for one streaming result, with a high/low watermark autopull
      # policy. Sits between the connection's reader (producer) and the cursor
      # (consumer). Server→driver flow control *is* the backpressure: the cursor
      # checks `pull_ready?` as it drains and, when the buffer has fallen to/below
      # the low watermark and the server has said `has_more`, issues the next
      # `PULL {n: fetch_size}` (marking it via `note_pull_issued`). Hysteresis
      # (high ≈ 2× fetch_size, low a fraction) keeps PULLs from thrashing. Because
      # the cursor only ever requests what it will drain, at most ~one batch sits
      # unread, so the queue is unbounded — `deliver_batch` never blocks. That
      # matters: the reader dispatches under the wire lock, so a blocking enqueue
      # could stall every request on the connection (docs/unified-pipeline.md).
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
          # Unbounded: the watermark gates how much the cursor pulls, so this never
          # grows past ~one batch of unread records. deliver_batch must not block —
          # the reader enqueues while holding the wire lock.
          @queue = Thread::Queue.new
          @mutex = Mutex.new
          @has_more = true        # server may have more records for this stream
          @pull_in_flight = true  # the first PULL is pipelined with RUN by the cursor
          @ended = false          # final SUCCESS/IGNORED seen → no more records
          @error = nil            # stream failed; re-raised to the consumer
          @summary = nil          # terminating SUCCESS metadata
        end

        # --- Producer (reader) side -----------------------------------------

        # Deliver a whole batch atomically: enqueue its records *and* clear the
        # pull-in-flight flag (recording whether the server has more) in one
        # synchronized step. The atomicity is the crux — a consumer that pops any
        # of these records and then checks the autopull policy is guaranteed to
        # see the matching has_more/pull-in-flight state, so it issues the next
        # PULL at the right time instead of parking on a stale "in flight" flag.
        # Never blocks (unbounded queue); the cursor's watermark bounds how much
        # the server ships.
        def deliver_batch(records, has_more:)
          @mutex.synchronize do
            records.each { |record| @queue.push(record) }
            @has_more = has_more
            @pull_in_flight = false
          end
        end

        # Final batch: deliver its records, stash the terminating SUCCESS metadata,
        # and close the queue so a consumer parked in shift wakes with nil.
        def finish(records = [], summary = nil)
          @mutex.synchronize do
            records.each { |record| @queue.push(record) }
            @summary = summary
            @ended = true
            @has_more = false
          end
          @queue.close
        end

        # The stream failed: deliver any records that preceded the failure in this
        # batch, then arm the error the consumer re-raises once the queue drains.
        def fail(error, records = [])
          @mutex.synchronize do
            records.each { |record| @queue.push(record) }
            @error ||= error
            @ended = true
            @has_more = false
          end
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
