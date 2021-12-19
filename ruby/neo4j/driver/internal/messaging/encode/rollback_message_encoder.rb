module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class RollbackMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::RollbackMessage)
            packer.pack_struct_header(0, Request::RollbackMessage::SIGNATURE)
          end
        end
      end
    end
  end
end
