module Neo4j::Driver
  module Internal
    module Handlers
      class ChannelReleasingResetResponseHandler < ResetResponseHandler
        def initialize(channel, pool, message_dispatcher, log, release_future)
          super(message_dispatcher, release_future)
          @channel = channel
          @pool = pool
          @log = log
        end

        def reset_completed(success)
          if success
            # update the last-used timestamp before returning the channel back to the pool
            # Async::Connection::ChannelAttributes.set_last_used_timestamp(@channel, @clock.millis)
            # closure_stage = Util::Futures.completed_with_null
          else
            # close the channel before returning it back to the pool if RESET failed
            @channel.close
          end
        rescue
          nil
        ensure
          @pool.release(@channel)
          @log.debug { "Channel #{@channel.object_id} released." }
        end
      end
    end
  end
end
