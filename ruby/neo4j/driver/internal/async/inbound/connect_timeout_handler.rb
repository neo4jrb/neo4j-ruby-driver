module Neo4j::Driver
  module Internal
    module Async
      module Inbound

        # Handler needed to limit amount of time connection performs TLS and Bolt handshakes.
        # It should only be used when connection is established and removed from the pipeline afterwards.
        # Otherwise it will make long running queries fail.
        class ConnectTimeoutHandler
          attr_reader :timeout_millis
          attr_accessor :triggered

          def initialize(timeout_millis)
            io.netty.handler.timeout.ReadTimeoutHandler.new(timeout_millis)
            @timeout_millis = timeout_millis
          end

          def read_timed_out(ctx)
            unless triggered
              triggered = true
              ctx.fire_exception_caught(unable_to_connect_error)
            end
          end

          private

          def unable_to_connect_error
            Neo4j::Driver::Exceptions::ServiceUnavailableException.new("Unable to establish connection in #{timeout_millis}ms")
          end
        end
      end
    end
  end
end
