# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # The wire handler for a streaming PULL/DISCARD: the dedicated reader routes
      # the result's replies here, and it fills the result's RecordBuffer.
      #
      # It accumulates a whole batch's records and hands them to the buffer
      # *together with* the batch's has_more flag, in one atomic delivery, only
      # once the batch's terminal reply (SUCCESS/FAILURE/IGNORED) arrives. That
      # atomicity is what makes the cursor's consumer-driven autopull correct
      # under true parallelism (JRuby): a consumer can never observe a record
      # without also observing the has_more/pull-in-flight state that goes with
      # it, so its post-shift watermark check always issues the next PULL at the
      # right moment. (Pushing records as they arrived, then flipping the flag on
      # the later SUCCESS, let the consumer drain and park before the flag flipped
      # — a lost-pull deadlock. See docs/unified-pipeline.md.)
      #
      # Runs in the reader thread; @batch is reader-local (no other thread touches
      # it). Same visitor interface as @collector, so the wire dispatches to it
      # identically.
      class StreamHandler
        def initialize(buffer)
          @buffer = buffer
          @batch = []
        end

        def on_record(message)
          @batch << message
        end

        def on_success(message)
          batch = take_batch
          if message.metadata[:has_more]
            @buffer.deliver_batch(batch, has_more: true)
          else
            @buffer.finish(batch, message.metadata)
          end
        end

        def on_failure(message)
          # Deliver any records that preceded the failure in this batch (e.g.
          # UNWIND [1,0,2]/x yields record(10) then FAILURE), then the error.
          @buffer.fail(message.to_exception, take_batch)
        end

        def on_ignored(_message)
          @buffer.finish(take_batch)
        end

        # Connection failure fan-out (see Connection#fan_out / Wire#fail_pending):
        # surface the error to a consumer parked in buffer.shift. The current
        # partial batch is incomplete, so drop it — only the error matters.
        def fail(error)
          @buffer.fail(error)
        end

        private

        def take_batch
          batch = @batch
          @batch = []
          batch
        end
      end
    end
  end
end
