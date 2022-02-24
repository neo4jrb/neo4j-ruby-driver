module Neo4j::Driver
  module Internal
    module Logging
      class Slf4jLogger
        delegate :trace_enabled?, :debug_enabled?, to: :@delegate

        def initialize(delegate)
          @delegate = java.util.Objects.require_non_null(delegate)
        end

        def error(message, cause)
          if @delegate.error_enabled?
            @delegate.error(message, cause)
          end
        end

        def info(message, params)
          if @delegate.info_enabled?
            @delegate.info(format_message(message, params))
          end
        end

        def warn(message, params)
          if @delegate.warn_enabled?
            @delegate.warn(format_message(message, params))
          end
        end

        def debug(message, params)
          if @delegate.debug_enabled?
            @delegate.debug(format_message(message, params))
          end
        end

        def trace(message, params)
          if @delegate.trace_enabled?
            @delegate.trace(format_message(message, params))
          end
        end

        private

        # Creates a fully formatted message. Such formatting is needed because driver uses {@link String#format(String, Object...)} parameters in message
        # templates, i.e. '%s' or '%d' while SLF4J uses '{}'. Thus this logger passes fully formatted messages to SLF4J.

        # @param messageTemplate the message template.
        # @param params the parameters.
        # @return fully formatted message string.
        def format_message(message_template, params)
          "#{message_template}#{params}"
        end
      end
    end
  end
end
