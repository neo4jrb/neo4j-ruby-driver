# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # The wire handler for a streaming PULL/DISCARD: the dedicated reader routes
      # the result's replies here, and it fills the result's RecordBuffer. Records
      # block at the buffer's bound (consumer backpressure); a has_more SUCCESS
      # marks the batch done (the cursor decides whether to PULL again); a final
      # SUCCESS/FAILURE/IGNORED ends the stream. The cursor consumes the buffer
      # and drives follow-up PULLs — this side only fills.
      #
      # Runs in the reader thread/fiber. Same visitor interface as @collector, so
      # the wire dispatches to it identically.
      class StreamHandler
        def initialize(buffer)
          @buffer = buffer
        end

        def on_record(message)
          @buffer.push_record(message)
        end

        def on_success(message)
          if message.metadata[:has_more]
            @buffer.batch_complete(has_more: true)
          else
            @buffer.finish(message.metadata)
          end
        end

        def on_failure(message)
          @buffer.fail(message.to_exception)
        end

        def on_ignored(_message)
          @buffer.finish
        end

        # Connection failure fan-out (see Connection#fan_out / Wire#fail_pending):
        # surface the error to a consumer parked in buffer.shift.
        def fail(error)
          @buffer.fail(error)
        end
      end
    end
  end
end
