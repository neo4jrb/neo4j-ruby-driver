module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class ChannelErrorHandler
          attr_accessor :logging, :message_dispatcher, :log, :error_log, :failed

          def initialize(logging)
            @logging = logging
          end

          def handler_added(ctx)
            @message_dispatcher = java.util.Objects.require_non_null(::Connection::ChannelAttributes.message_dispatcher(ctx.channel))
            @log = Logging::ChannelActivityLogger.new(ctx.channel, logging, get_class)
            @error_log = Logging::ChannelErrorLogger.new(ctx.channel, logging)
          end

          def handler_removed(ctx)
            message_dispatcher = nil
            log = nil
            failed = nil
          end

          def channel_inactive(ctx)
            log.debug

            termination_reason = ::Connection::ChannelAttributes.termination_reason(ctx.channel)
            error = ::Util::ErrorUtil.new_connection_terminated_error(termination_reason)

            if failed

              # channel became inactive not because of a fatal exception that came from exceptionCaught
              # it is most likely inactive because actual network connection broke or was explicitly closed by the driver
              message_dispatcher.handle_channel_inactive(error)
              ctx.channel.close
            else
              fail(error)
            end
          end

          def exception_caught(ctx, error)
            if failed
              error_log.trace_or_debug('Another fatal error occurred in the pipeline', error)
            else
              failed = true
              log_unexpected_error_warning(error)
              fail(error)
            end
          end

          private

          def log_unexpected_error_warning(error)
            unless error.kind_of?(Neo4j::Driver::Exceptions::ConnectionReadTimeoutException)
              error_log.trace_or_debug('Fatal error occurred in the pipeline', error)
            end
          end

          def fail(error)
            cause = transform_error(error)
            message_dispatcher.handle_channel_error(cause)
          end

          class << self
            def transform_error(error)
              # unwrap the CodecException if it has a cause
              error = error.get_cause if error.kind_of?(io.netty.handler.codec.CodecException) && !error.get_cause.nil?

              if error.kind_of?(java.io.IOException)
                return Neo4j::Driver::Exceptions::ServiceUnavailableException.new('Connection to the database failed', error)
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
