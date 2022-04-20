module Neo4j::Driver
  module Internal
    module Handlers
      class RoutingResponseHandler
        include Spi::ResponseHandler
        delegate :on_success, :on_record, :can_manage_auto_read, :disable_auto_read_management, to: :@delegate

        def initialize(delegate, address, access_mode, error_handler)
          @delegate = delegate
          @address = address
          @access_mode = access_mode
          @error_handler = error_handler
        end

        def on_failure(error)
          new_error = handled_error(error)
          @delegate.on_failure(new_error)
        end

        private

        def handled_error(received_error)
          # TODO: probably not necessary with concurrent-ruby as it might not wrap exceptions like java
          error = Futures.completion_exception_cause(received_error)

          case error
          when Exceptions::ServiceUnavailableException
            handled_service_unavailable_exception(error)
          when Exceptions::ClientException
            handled_client_exception(error)
          when Exceptions::TransientException
            handled_transient_exception(error)
          else
            error
          end
        end

        def handled_service_unavailable_exception(e)
          @error_handler.on_connection_failure(@address)
          Exceptions::SessionExpiredException("Server at #{@address} is no longer available", e)
        end

        def handled_transient_exception(e)
          e.code == "Neo.TransientError.General.DatabaseUnavailable" ? error_handler.on_connection_failure(@address) : e
        end

        def handled_client_exception(e)
          return e unless failure_to_write?(e)

          # The server is unaware of the session mode, so we have to implement this logic in the driver.
          # In the future, we might be able to move this logic to the server.
          case @access_mode
          when AccessMode::READ
            Exceptions::ClientException.new('Write queries cannot be performed in READ access mode.')
          when AccessMode::WRITE
            @error_handler.on_write_failure(@address)
            Exceptions::SessionExpiredException.new('Server at %s no longer accepts writes' % @address)
          else
            raise ArgumentError, @accessMode + ' not supported.'
          end
        end

        def failure_to_write?(e)
          %w[Neo.ClientError.Cluster.NotALeader
             Neo.ClientError.General.ForbiddenOnReadOnlyDatabase].include?(e.code)
        end
      end
    end
  end
end
