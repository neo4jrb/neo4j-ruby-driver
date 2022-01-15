module Neo4j::Driver
  module Internal
    module Logging
      class NettyLogger < org.neo4j.driver.internal.shaded.io.netty.util.internal.logging.AbstractInternalLogger
        PLACE_HOLDER_PATTERN = "\\{\\}"

        delegate :trace_enabled?, :debug_enabled?, to: :@log

        def initialize(name, log)
          super(name)
          @log = log
        end

        def trace(format, arg_a, arg_b)
          @log.trace(to_driver_logger_format(format), arg_a, arg_b)
        end

        def debug(format, arg_a, arg_b)
          @log.debug(to_driver_logger_format(format), arg_a, arg_b)
        end

        def info_enabled?
          true
        end

        def info(format, arg_a, arg_b)
          @log.info(to_driver_logger_format(format), arg_a, arg_b)
        end

        def warn_enabled?
          true
        end

        def warn(format, arg_a, arg_b)
          @log.warn(to_driver_logger_format(format), arg_a, arg_b)
        end

        def error_enabled?
          true
        end

        def error(msg, t)
          @log.error(msg, t)
        end

        private

        def to_driver_logger_format(format)
          PLACE_HOLDER_PATTERN.match(format).gsub!('%s', '')
        end
      end
    end
  end
end
