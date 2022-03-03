module Neo4j::Driver
  module Internal
    module Logging
      # Internal implementation of the SLF4J logging.
      # <b>This class should not be used directly.</b> Please use {@link Logging#slf4j()} factory method instead.

      # @see Logging#slf4j()
      class Slf4jLogging
        include Logging
        include java.io.Serializable

        def log(name)
          Slf4jLogger.new(org.slf4j.LoggerFactory.logger(name))
        end

        def self.check_availability
          begin
            java.lang.Class.for_name('org.slf4j.LoggerFactory')
            nil
          rescue StandardError => error
            Exceptions::IllegalStateException.new('SLF4J logging is not available. Please add dependencies on slf4j-api and SLF4J binding (Logback, Log4j, etc.)', error)
          end
        end
      end
    end
  end
end
