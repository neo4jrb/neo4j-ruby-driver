module Neo4j::Driver
  module Internal
    module Logging
      class JULogger
        attr_reader :debug_enabled, :trace_enabled

        def initialize(name, logging_level)
          @delegate = java.util.logging.Logger.get_logger(name)
          @delegate.set_level(logging_level)
          @debug_enabled = @delegate.loggable?(java.util.logging.Level::FINE)
          @trace_enabled = @delegate.loggable?(java.util.logging.Level::FINEST)
        end

        def error(message, cause)
          @delegate.log(java.util.logging.Level::SEVERE, message, cause)
        end

        def info(format, params)
          @delegate.log(java.util.logging.Level::INFO, "#{format}#{params}")
        end

        def warn(format, params)
          @delegate.log(java.util.logging.Level::WARNING, "#{format}#{params}")
        end

        def debug(format, params)
          if debug_enabled
            @delegate.log(java.util.logging.Level::FINE, "#{format}#{params}")
          end
        end

        def trace(format, params)
          if trace_enabled
            @delegate.log(java.util.logging.Level::FINEST, "#{format}#{params}")
          end
        end
      end
    end
  end
end
