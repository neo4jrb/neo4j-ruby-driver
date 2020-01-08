# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module ErrorHandling
        def check_error(error_code, status = nil)
          case error_code
            # Identifies a successful operation which is defined as 0
          when Bolt::Error::BOLT_SUCCESS # 0
            nil

            # Permission denied
          when Bolt::Error::BOLT_PERMISSION_DENIED # 7
            throw Exceptions::AuthenticationException.new(error_code, 'Permission denied')

            # Connection refused
          when Bolt::Error::BOLT_CONNECTION_REFUSED # 11
            throw Exceptions::ServiceUnavailableException.new(error_code, 'unable to acquire connection')

            # Connection pool is full
          when Bolt::Error::BOLT_POOL_FULL # 0x600
            throw Exceptions::ClientException.new(
              error_code,
              'Unable to acquire connection from the pool within configured maximum time of ' \
              "#{DurationNormalizer.milliseconds(@config[:connection_acquisition_timeout])}ms"
            )

            # Routing table retrieval failed
          when Bolt::Error::BOLT_ROUTING_UNABLE_TO_RETRIEVE_ROUTING_TABLE # 0x800
            throw Exceptions::ServiceUnavailableException.new(
              error_code,
              'Could not perform discovery. No routing servers available.'
            )

            # Error set in connection
          when Bolt::Error::BOLT_CONNECTION_HAS_MORE_INFO, Bolt::Error::BOLT_STATUS_SET # 0xFFE, 0xFFF
            status = Bolt::Connection.status(bolt_connection)
            unqualified_error(error_code, status)
          else
            unqualified_error(error_code, status)
          end
        end

        def on_failure(_error); end

        def check_status(status)
          check_error(Bolt::Status.get_error(status), status)
        end

        def with_status
          status = Bolt::Status.create
          yield status
        ensure
          check_status(status)
        end

        def new_neo4j_error(code:, message:)
          case code.split('.')[1]
          when 'ClientError'
            if code.casecmp('Neo.ClientError.Security.Unauthorized').zero?
              Exceptions::AuthenticationException
            else
              Exceptions::ClientException
            end
          when 'TransientError'
            Exceptions::TransientException
          else
            Exceptions::DatabaseException
          end.new(code, message)
        end

        private

        def exception_class(state)
          case state
          when Bolt::Status::BOLT_CONNECTION_STATE_DEFUNCT
            Exceptions::SessionExpiredException
          else
            Exceptions::Neo4jException
          end
        end

        def throw(error)
          on_failure(error)
          raise error
        end

        def unqualified_error(error_code, status)
          details = details(error_code, status)
          throw exception_class(details[:state]).new(error_code,
                                                     details.map { |key, value| "#{key}: `#{value}`" }.join(', '))
        end

        def details(error_code, status)
          details = {
            code: error_code.to_s(16),
            error: Bolt::Error.get_string(error_code),
          }
          return details unless status
          details.merge(state: Bolt::Status.get_state(status),
                        error: Bolt::Status.get_error(status),
                        error_context: Bolt::Status.get_error_context(status))
        end
      end
    end
  end
end
