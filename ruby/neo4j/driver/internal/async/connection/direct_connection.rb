module Neo4j::Driver
  module Internal
    module Async
      module Connection
        # This is a connection used by {@link DirectConnectionProvider} to connect to a remote database.
        class DirectConnection < Struct.new(:delegate, :database_name, :mode, :impersonated_user)
          delegate *%i[enable_auto_read disable_auto_read reset open? release terminate_and_release server_agent
          server_address server_version protocol flush], to: :delegate
          alias connection delegate

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
        end
      end
    end
  end
end