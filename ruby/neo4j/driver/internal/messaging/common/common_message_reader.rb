module Neo4j::Driver
  module Internal
    module Messaging
      module Common
        class CommonMessageReader
          def initialize(input)
            @unpacker = CommonValueUnpacker.new(input)
          end

          def read(handler)
            @unpacker.unpack_struct_header
            type = @unpacker.unpack_struct_signature

            case type
            when Response::SuccessMessage::SIGNATURE
              unpack_success_message(handler)
            when Response::FailureMessage::SIGNATURE
              unpack_failure_message(handler)
            when Response::IgnoredMessage::SIGNATURE
              unpack_ignored_message(handler)
            when Response::RecordMessage::SIGNATURE
              unpack_record_message(handler)
            else
              raise java.io.IOException, "Unknown message type: #{type}"
            end
          end

          private

          def unpack_success_message(output)
            map = @unpacker.unpack_map
            output.handle_success_message(map)
          end

          def unpack_failure_message(output)
            params = @unpacker.unpack_map
            code = params['code']
            message = params['message']
            output.handle_failure_message(code, message)
          end

          def unpack_ignored_message(output)
            output.handle_ignored_message
          end

          def unpack_record_message(output)
            fields = @unpacker.unpack_array
            output.handle_record_message(fields)
          end
        end
      end
    end
  end
end
