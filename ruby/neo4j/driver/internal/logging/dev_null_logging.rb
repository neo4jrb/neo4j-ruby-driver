module Neo4j::Driver
  module Internal
    module Logging
      class DevNullLogging
        include Logging
        include java.io.Serializable

        DEV_NULL_LOGGING = new

        def initialize
          @serial_version_ui_d = -2632752338512373821
        end

        def log(_name)
          DevNullLogger::DEV_NULL_LOGGER
        end
      end
    end
  end
end
