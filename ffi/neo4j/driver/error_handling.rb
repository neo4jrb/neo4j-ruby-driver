# frozen_string_literal: true
module Neo4j
  module Driver
    module ErrorHandling
      def check_and_print_error(connection = @connection, status = Bolt::Connection.status(connection),
                                error_text = nil)
        error_code = Bolt::Status.error(status)
        return Bolt::Error::BOLT_SUCCESS if error_code == Bolt::Error::BOLT_SUCCESS

        if error_code == Bolt::Error::BOLT_SERVER_FAILURE
          string_buffer = FFI::Buffer.alloc_out(:char, 4096)
          string_buffer[4095] = 0 if Bolt::Value.to_string(Bolt::Connection.failure(connection),
                                                           string_buffer.pointer, 4096, connection) > 4096
          puts("#{error_text || 'server failure'}: #{string_buffer.get_string(0)}")
        else
          error_ctx = Bolt::Status.error_context(status)
          puts("#{error_text || 'Bolt failure'} (code: #{error_code.to_s(16)}, " \
           "text: #{Bolt::Error.get_string(error_code)}, context: #{error_ctx})")
        end
        error_code
      end

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
           "text: #{Bolt::Error.get_string(error_code)}, context: #{error_ctx})")
        end
      end

      def check_status(status)
        check_error(Bolt::Status.error(status))
     end
    end
  end
end
