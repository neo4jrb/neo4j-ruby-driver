# frozen_string_literal: true

module Neo4j
  module Driver
    class Logger
      include org.neo4j.driver.Logger
      include org.neo4j.driver.Logging

      delegate :debug?, to: :@logger

      def initialize(logger)
        @logger = logger
      end

      def get_log(_name)
        self
      end

      def error(*args)
        add(::Logger::ERROR, format(*args))
      end

      def info(*args)
        add(::Logger::INFO, format(*args))
      end

      def warn(*args)
        add(::Logger::WARN, format(*args))
      end

      def debug(*args)
        add(::Logger::DEBUG, format(*args))
      end

      alias trace debug

      def trace_enabled?
        debug?
      end

      def debug_enabled
        debug?
      end

      private

      def add(level, *args)
        @logger.add(level) { format(*args) }
      end

      def format(*args)
        args.unshift('%s%n%s') if args.last.is_a? java.lang.Throwable
        java.lang.String.format(*args)
      end
    end
  end
end
