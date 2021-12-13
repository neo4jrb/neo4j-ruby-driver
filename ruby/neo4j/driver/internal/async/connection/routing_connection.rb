module Neo4j::Driver
  module Internal
    module Async
      module Connection
        # A connection used by the routing driver.
        class RoutingConnection < Struct.new(:delegate, :database_name, :access_mode, :impersonated_user, :error_handler)
          delegate *%i[enable_auto_read disable_auto_read reset open? release terminate_and_release server_agent
          server_address server_version protocol flush], to: :delegate
          alias mode access_mode

          def write(message1, handler1, message2 = nil, handler2 = nil)
            if message2.present? && handler2.present?
              delegate.write(message1, handler1, message2, handler2)
            else
              delegate.write(message1, handler1)
            end
          end

          def write_and_flush(message1, handler1, message2 = nil, handler2 = nil)
            if message2.present? && handler2.present?
              delegate.write_and_flush(message1, handler1, message2, handler2)
            else
              delegate.write_and_flush(message1, handler1)
            end
          end

          private

          def new_routing_response_handler(handler)
            Handlers::RoutingResponseHandler.new(handler, server_address, access_mode, error_handler)
          end
        end
      end
    end
  end
end
