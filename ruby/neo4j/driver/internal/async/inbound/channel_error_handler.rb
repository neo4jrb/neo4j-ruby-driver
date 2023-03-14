module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class ChannelErrorHandler
          def initialize(logger)
            @logger = logger
          end

          def handler_added(ctx)
            @message_dispatcher = java.util.Objects.require_non_null(Connection::ChannelAttributes.message_dispatcher(ctx.channel))
            @log = Logging::ChannelActivityLogger.new(ctx.channel, @logger, self.class)
            @error_log = Logging::ChannelErrorLogger.new(ctx.channel, @logger)
          end

          def handler_removed(ctx)
            @message_dispatcher = @log = nil
            @failed = false
          end

          def channel_inactive(ctx)
            @log.debug('Channel is inactive')

            termination_reason = Connection::ChannelAttributes.termination_reason(ctx.channel)
            error = Util::ErrorUtil.new_connection_terminated_error(termination_reason)

            if @failed

              # channel became inactive not because of a fatal exception that came from exceptionCaught
              # it is most likely inactive because actual network connection broke or was explicitly closed by the driver
              @message_dispatcher.handle_channel_inactive(error)
              ctx.channel.close
            else
              fail(error)
            end
          end

          def exception_caught(ctx, error)
            if @failed
              @error_log.debug('Another fatal error occurred in the pipeline', error)
            else
              @failed = true
              log_unexpected_error_warning(error)
              fail(error)
            end
          end

          private

          def log_unexpected_error_warning(error)
            unless error.is_a?(Exceptions::ConnectionReadTimeoutException)
              @error_log.debug('Fatal error occurred in the pipeline', error)
            end
          end

          def fail(error)
            cause = transform_error(error)
            @message_dispatcher.handle_channel_error(cause)
          end

          class << self
            def transform_error(error)
              # unwrap the CodecException if it has a cause
              error = error.cause if error.is_a?(io.netty.handler.codec.CodecException) && error.cause

              if error.is_a?(java.io.IOException)
                Neo4j::Driver::Exceptions::ServiceUnavailableException.new('Connection to the database failed', error)
              else
                error
              end
            end
          end
        end
      end
    end
  end
end
