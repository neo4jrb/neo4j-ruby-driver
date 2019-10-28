# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Logger
        # include org.neo4j.driver.v1.Logger

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

        def format(*args)
          args.unshift('%s%n%s') if args.last.is_a? java.lang.Throwable
          java.lang.String.format(*args)
        end
      end
    end
  end
end
