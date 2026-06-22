# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # The prefetch pump: moves a result's responses off a connection into a
      # RecordBuffer ahead of demand, pacing the server with watermark-gated
      # PULLs. The only concurrency-aware moving part — but it's tiny and
      # identical whether it runs on a Thread or a Fiber (Executor decides), and
      # whether the source reads block (thread) or yield (reactor).
      #
      # It drives a minimal `source` so it stays unit-testable without a socket:
      #   * `source.next_response` → the next Bolt message (Record / Success /
      #     Failure / Ignored), in order;
      #   * `source.pull(n)` → request the next batch of `n` records.
      # The first batch's PULL is assumed already sent by the cursor (RUN+PULL
      # pipelining); the pump issues every subsequent PULL.
      #
      # Messages dispatch through their own `accept` visitor, so there's no
      # case/when on response type here.
      class Pump
        def initialize(source, buffer)
          @source = source
          @buffer = buffer
          @running = false
          @cancelled = false
        end

        # Run the fill loop until the stream ends, fails, or is cancelled. Any
        # unexpected error is handed to the consumer via the buffer (re-raised
        # on its next read) — the stdlib-fiber pump propagates errors manually.
        def run
          @running = true
          @source.next_response.accept(self) while @running && !@cancelled
        rescue StandardError => e
          @buffer.fail(e)
        end

        # Cooperative cancel (cursor closed early). Ends the buffer so a pump
        # parked in await_pull_capacity wakes; the loop stops between responses.
        def cancel
          @cancelled = true
          @buffer.finish
        end

        # --- Response visitor (Bolt::Message#accept dispatches here) --------

        def on_record(message)
          # push_record blocks at the buffer's bound — that block is the
          # consumer backpressure (fill no further than the high watermark).
          @buffer.push_record(message)
        end

        def on_success(message)
          if message.metadata[:has_more]
            @buffer.batch_complete(has_more: true)
            # Hysteresis: wait until the buffer has drained to the low watermark
            # before asking the server for the next batch (false ⇒ ended/cancelled).
            if @buffer.await_pull_capacity
              @source.pull(@buffer.fetch_size)
            else
              @running = false
            end
          else
            @buffer.finish
            @running = false
          end
        end

        def on_failure(message)
          @buffer.fail(message.to_exception)
          @running = false
        end

        def on_ignored(_message)
          @buffer.finish
          @running = false
        end
      end
    end
  end
end
