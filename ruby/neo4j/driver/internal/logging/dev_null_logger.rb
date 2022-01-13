module Neo4j::Driver
  module Internal
    module Logging
      class DevNullLogger

        DEV_NULL_LOGGER = new

        def initialize
        end

        def error(message, cause)
        end

        def info(message, params)
        end

        def warn(message, params)
        end

        def debug(message, params)
        end

        def trace(message, params)
        end

        def trace_enabled?
          false
        end

        def debug_enabled?
          false
        end
      end
    end
  end
end
