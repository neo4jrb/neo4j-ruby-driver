module Neo4j
  module Driver
    module Logging1
      # Obtain a {@link Logger} instance by class, its name will be the fully qualified name of the class.

      # @param clazz class whose name should be used as the {@link Logger} name.
      # @return {@link Logger} instance
      private

      def log(clazz)
        canonical_name = clazz.canonical_name
        log(canonical_name.nil? ? clazz.name : canonical_name)
      end

      # Create logging implementation that uses SLF4J.

      # @return new logging implementation.
      # @throws IllegalStateException if SLF4J is not available.
      def slf4j
        unavailability_error = Internal::Logging::Slf4jLogging.check_availability

        raise unavailability_error unless unavailability_error.nil?

        Slf4jLogging.new
      end

      # Create logging implementation that uses {@link java.util.logging}.

      # @param level the log level.
      # @return new logging implementation.
      def java_util_logging(level)
        Internal::Logging::JULogging.new(level)
      end

      # Create logging implementation that uses {@link java.util.logging} to log to {@code System.err}.

      # @param level the log level.
      # @return new logging implementation.
      def console(level)
        Internal::Logging::ConsoleLogging.new(level)
      end

      # Create logging implementation that discards all messages and logs nothing.

      # @return new logging implementation.
      def none
        Internal::Logging::DevNullLogging::DEV_NULL_LOGGING
      end
    end
  end
end