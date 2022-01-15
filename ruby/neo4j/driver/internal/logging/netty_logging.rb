module Neo4j::Driver
  module Internal
    module Logging
      # This is the logging factory to delegate netty's logging to our logging system
      class NettyLogging < org.neo4j.driver.internal.shaded.io.netty.util.internal.logging.InternalLoggerFactory
        def initialize(logging)
          @logging = logging
        end

        def new_instance(name)
          NettyLogger.new(name, @logging.log(name))
        end
      end
    end
  end
end
