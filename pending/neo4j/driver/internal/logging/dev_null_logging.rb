module Neo4j::Driver
  module Internal
    module Logging
      class DevNullLogging
        include Logging
        include java.io.Serializable

        DEV_NULL_LOGGING = new

        def log(_name)
          DevNullLogger::DEV_NULL_LOGGER
        end
      end
    end
  end
end
