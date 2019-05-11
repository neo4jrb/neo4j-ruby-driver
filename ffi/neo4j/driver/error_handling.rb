# frozen_string_literal: true

module Neo4j
  module Driver
    module ErrorHandling
      def check_error(error_code, error_text = nil)
        case error_code
          # Identifies a successful operation which is defined as 0
        when Bolt::Error::BOLT_SUCCESS # 0
          nil
          # Permission denied
        when Bolt::Error::BOLT_PERMISSION_DENIED # 7
          raise Exceptions::AuthenticationException.new(error_code, 'Permission denied')
          # Connection refused
        when Bolt::Error::BOLT_CONNECTION_REFUSED
          raise Exceptions::ServiceUnavailableException.new(error_code, 'unable to acquire connection')
        else
          error_ctx = Bolt::Status.error_context(status)
          raise Exceptions::Neo4jException.new(
            error_code,
            "#{error_text || 'Unknown Bolt failure'} (code: #{error_code.to_s(16)}, " \
           "text: #{Bolt::Error.get_string(error_code)}, context: #{error_ctx})"
          )
        end
      end

      def check_status(status)
        check_error(Bolt::Status.error(status))
      end
    end
  end
end
