# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      class Logger
        include org.neo4j.driver.Logger
        include org.neo4j.driver.Logging
        extend Forwardable

        delegate debug?: :@logger

        def initialize(logger)
          @logger = logger
        end

        def getLog(_name)
          self
        end
        alias get_log getLog

        def error(*args) = log(::Logger::ERROR, *args)

        def info(*args) = log(::Logger::INFO, *args)

        def warn(*args) = log(::Logger::WARN, *args)

        def debug(*args) = log(::Logger::DEBUG, *args)
        alias trace debug

        def trace_enabled?
          debug?
        end

        def debug_enabled
          debug?
        end

        private

        def log(level, *args)
          @logger.add(level) { format(*args) }
        end

        def format(message, *args)
          return message.to_s if args.empty? && !message.is_a?(java.lang.Throwable)
          args.unshift(message)
          args.unshift('%s%n%s') if args.last.is_a?(java.lang.Throwable)
          java.lang.String.format(*args)
        end
      end
    end
  end
end
