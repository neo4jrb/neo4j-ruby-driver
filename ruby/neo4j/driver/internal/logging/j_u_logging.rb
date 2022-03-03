module Neo4j::Driver
  module Internal
    module Logging
      # Internal implementation of the JUL.
      # <b>This class should not be used directly.</b> Please use {@link Logging#javaUtilLogging(Level)} factory method instead.

      # @see Logging#javaUtilLogging(Level)
      class JULogging
        include Logging
        include java.io.Serializable

        def initialize(logging_level)
          @logging_level = logging_level
          @serial_version_ui_d = -1145576859241657833
        end

        def log(name)
          JULogger.new(name, @logging_level)
        end
      end
    end
  end
end
