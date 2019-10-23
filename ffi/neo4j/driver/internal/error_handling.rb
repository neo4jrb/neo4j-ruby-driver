# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module ErrorHandling
        def check_error(error_code, status = nil, error_text = nil)
          case error_code
            # Identifies a successful operation which is defined as 0
          when Bolt::Error::BOLT_SUCCESS # 0
            nil
            # Permission denied
          when Bolt::Error::BOLT_PERMISSION_DENIED # 7
            throw Exceptions::AuthenticationException.new(error_code, 'Permission denied')
            # Connection refused
          when Bolt::Error::BOLT_CONNECTION_REFUSED
            throw Exceptions::ServiceUnavailableException.new(error_code, 'unable to acquire connection')
            # Error set in connection
          when Bolt::Error::BOLT_CONNECTION_HAS_MORE_INFO, Bolt::Error::BOLT_STATUS_SET
            status = Bolt::Connection.status(bolt_connection)
            unqualified_error(error_code, status, error_text)
          else
            unqualified_error(error_code, status, error_text)
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

        private

        def throw(error)
          on_failure(error)
          raise error
        end

        def unqualified_error(error_code, status, error_text)
          error_ctx = status && Bolt::Status.get_error_context(status)
          throw Exceptions::Neo4jException.new(
            error_code,
            "#{error_text || 'Unknown Bolt failure'} (code: #{error_code.to_s(16)}, " \
           "text: #{Bolt::Error.get_string(error_code)}, context: #{error_ctx})"
          )
        end
      end
    end
  end
end
