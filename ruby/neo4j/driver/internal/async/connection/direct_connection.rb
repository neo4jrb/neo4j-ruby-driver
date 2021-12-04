module Neo4j::Driver
  module Internal
    module Async
      module Connection

        # This is a connection used by {@link DirectConnectionProvider} to connect to a remote database.
        class DirectConnection < Struct.new(:delegate, :database_name, :mode, :impersonated_user)

          def connection
            delegate
          end

          def is_open?
            delegate.is_open?
          end

          def enable_auto_read
            delegate.enable_auto_read
          end

          def disable_auto_read
            delegate.disable_auto_read
          end

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

          def reset
            delegate.reset
          end

          def release
            delegate.release
          end

          def terminate_and_release(reason)
            delegate.terminate_and_release(reason)
          end

          def server_agent
            delegate.server_agent
          end

          def server_address
            delegate.server_address
          end

          def server_version
            delegate.server_version
          end

          def protocol
            delegate.protocol
          end

          def mode
            mode
          end

          def database_name
            database_name
          end

          def impersonated_user
            impersonated_user
          end

          def flush
            delegate.flush
          end
        end
      end
    end
  end
end