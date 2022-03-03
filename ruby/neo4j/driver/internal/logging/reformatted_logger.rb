module Neo4j::Driver
  module Internal
    module Logging
      class ReformattedLogger
        delegate :debug_enabled?, :trace_enabled?, to: :@delegate

        def initialize(delegate)
          @delegate = java.util.Objects.require_non_null(delegate)
        end

        def error(message, cause)
          @delegate.error(reformat(message), cause)
        end

        def info(message, params)
          @delegate.info(reformat(message), params)
        end

        def warn(message, cause)
          @delegate.warn(reformat(message), cause)
        end

        def debug(message, params)
          @delegate.debug(reformat(message), params) if debug_enabled?
        end

        def trace(message, params)
          @delegate.trace(reformat(message), params) if trace_enabled?
        end

        def reformat(message)
        end
      end
    end
  end
end
