module Neo4j::Driver
  module Internal
    module Handlers
      class ChannelReleasingResetResponseHandler < ResetResponseHandler
        def initialize(channel, pool, message_dispatcher, clock, release_future)
          super(message_dispatcher, release_future)
          @channel = channel
          @pool = pool
          @clock = clock
        end

        def reset_completed(completion_future, success)
          if success
            # update the last-used timestamp before returning the channel back to the pool
            Async::Connection::ChannelAttributes.set_last_used_timestamp(@channel, @clock.millis)
            closure_stage = Util::Futures.completed_with_null
          else
            # close the channel before returning it back to the pool if RESET failed
            closure_stage = Util::Futures.as_completion_stage(@channel.close)
          end

          closure_stage.exceptionally(-> (_throwable) { nil }).then_compose(-> (_ignored) { @pool.release(@channel) }).when_complete do |_, _error|
            completion_future.complete(nil)
          end
        end
      end
    end
  end
end
