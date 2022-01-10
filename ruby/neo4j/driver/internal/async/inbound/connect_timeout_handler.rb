module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        # Handler needed to limit amount of time connection performs TLS and Bolt handshakes.
        # It should only be used when connection is established and removed from the pipeline afterwards.
        # Otherwise it will make long running queries fail.
        class ConnectTimeoutHandler < org.neo4j.driver.internal.shaded.io.netty.handler.timeout.ReadTimeoutHandler
          def initialize(timeout_millis)
            super(timeout_millis, java.util.concurrent.TimeUnit::MILLISECONDS)
            @timeout_millis = timeout_millis
          end

          protected

          def read_timed_out(ctx)
            unless @triggered
              @triggered = true
              ctx.fire_exception_caught(unable_to_connect_error)
            end
          end

          private

          def unable_to_connect_error
            Neo4j::Driver::Exceptions::ServiceUnavailableException.new("Unable to establish connection in #{@timeout_millis}ms")
          end
        end
      end
    end
  end
end
