module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class NettyChannelHealthChecker
          attr_reader :pool_settings, :clock, :logging, :log, :min_creation_timestamp_millis_opt

          def initialize(pool_settings, clock, logging)
            @pool_settings = pool_settings
            @clock = clock
            @logging = logging
            @log = logging.get_log(get_class)
            @min_creation_timestamp_millis_opt = java.util.concurrent.atomic.AtomicReference.new(java.util.Optional.empty)
          end

          def is_healthy(channel)
            return channel.event_loop.new_succeeded_future(false) if is_too_old?(channel)

            return ping(channel) if has_been_idle_for_too_long?(channel)

            ACTIVE.is_healthy(channel)
          end

          def on_expired(e, channel)
            ts = Connection::ChannelAttributes.creation_timestamp(channel)

            # Override current value ONLY if the new one is greater
            min_creation_timestamp_millis_opt.get_and_update do |prev|
              java.util.Optional.of(prev.filter(-> (prev_ts) { ts <= prev_ts }.or_else(ts)))
            end
          end

          private

          def is_too_old?(channel)
            creation_timestamp_millis = Connection::ChannelAttributes.creation_timestamp(channel)
            min_creation_timestamp_millis_opt = min_creation_timestamp_millis_opt.get

            if min_creation_timestamp_millis_opt.present? && creation_timestamp_millis <= min_creation_timestamp_millis_opt.get
              log.trace("The channel #{channel} is marked for closure as its creation timestamp is older than or equal to the acceptable minimum timestamp: #{creation_timestamp_millis} <= #{min_creation_timestamp_millis_opt.get}")
              return true
            end

            if pool_settings.max_connection_lifetime_enabled
              current_timestamp_millis = clock.millis

              age_millis = current_timestamp_millis - creation_timestamp_millis
              max_age_millis = pool_settings.max_connection_lifetime

              too_old = age_millis > max_age_millis

              if too_old
                log.trace("Failed acquire channel #{channel} from the pool because it is too old: #{age_millis} > #{max_age_millis}")
              end
              return too_old
            end

            false
          end

          def has_been_idle_for_too_long?(channel)
            if pool_settings.idle_time_before_connection_test_enabled?
              last_used_timestamp = Connection::ChannelAttributes.last_used_timestamp(channel)
              if !last_used_timestamp.nil?
                idle_time = clock.millis - last_used_timestamp
                idle_too_long = idle_time > pool_settings.idle_time_before_connection_test

                if idle_too_long
                  log.trace( "Channel #{channel} has been idle for #{idle_time} and needs a ping")
                end

                return idle_too_long
              end
            end
            false
          end

          def ping(channel)
            result = channel.event_loop.new_promise
            Connection::ChannelAttributes.message_dispatcher.enqueue(Handlers::PingResponseHandler.new(result, channel, logging))
            channel.write_and_flush(Messaging::Request::ResetMessage::RESET, channel.void_promise)
            result
          end
        end
      end
    end
  end
end
