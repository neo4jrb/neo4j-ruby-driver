module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class ConnectionReadTimeoutHandler #< org.neo4j.driver.internal.shaded.io.netty.handler.timeout.ReadTimeoutHandler
          def read_timeout(ctx)
            unless @triggered
              ctx.fire_exception_caught(Neo4j::Driver::Exception::ConnectionReadTimeoutException::INSTANCE)
              ctx.close
              @triggered = true
            end
          end
        end
      end
    end
  end
end
