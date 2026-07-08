# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # The wire handler for a streaming PULL/DISCARD: the dedicated reader routes
      # the result's replies here, and it fills the result's RecordBuffer.
      #
      # Records are forwarded to the buffer incrementally — the instant each is
      # decoded — so the cursor can read record 1 without waiting for the whole
      # batch. The batch's terminating SUCCESS resolves the buffer's has_more
      # promise (batch_complete) or ends the stream (finish); a FAILURE/IGNORED
      # ends it too. The cursor consumes the buffer and drives follow-up PULLs —
      # this side only fills.
      #
      # Runs in the reader thread; same visitor interface as @collector, so the
      # wire dispatches to it identically.
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
          # Records already delivered stay readable; the cursor hits this error
          # once it drains them (records that preceded the failure are valid).
          @buffer.fail(message.to_exception)
        end

        def on_ignored(_message)
          @buffer.finish
        end

        # Connection failure fan-out (see Connection#fan_out / Wire#fail_pending):
        # surface the error to a cursor parked in the buffer.
        def fail(error)
          @buffer.fail(error)
        end
      end
    end
  end
end
