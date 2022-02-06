module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class HandshakeCompletedListener

          def initialize(user_agent, auth_token, routing_context, connection_initialized_promise)
            @user_agent = java.util.Objects.require_non_null(user_agent)
            @auth_token = java.util.Objects.require_non_null(auth_token)
            @routing_context = routing_context
            @connection_initialized_promise = java.util.Objects.require_non_null(connection_initialized_promise)
          end

          def operation_complete(future)
            if future.success?
              protocol = Messaging::BoltProtocol.for_channel(future.channel)
              protocol.initialize_channel(@user_agent, @auth_token, @routing_context, @connection_initialized_promise)
            else
              @connection_initialized_promise.set_failure(future.cause)
            end
          end
        end
      end
    end
  end
end
