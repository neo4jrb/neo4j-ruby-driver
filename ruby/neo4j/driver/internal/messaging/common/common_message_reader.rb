module Neo4j::Driver
  module Internal
    module Messaging
      module Common
        class CommonMessageReader
          def initialize(input)
            @unpacker = input
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
              raise IOError, "Unknown message type: #{type}"
            end
          end

          private

          def unpack_success_message(output)
            map = @unpacker.unpack
            output.handle_success_message(map)
          end

          def unpack_failure_message(output)
            output.handle_failure_message(**@unpacker.unpack)
          end

          def unpack_ignored_message(output)
            output.handle_ignored_message
          end

          def unpack_record_message(output)
            fields = @unpacker.unpack
            output.handle_record_message(fields)
          end
        end
      end
    end
  end
end
