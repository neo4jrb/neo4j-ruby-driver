module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class ResetMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::ResetMessage)
            packer.pack_struct_header(0, Request::ResetMessage::SIGNATURE)
          end
        end
      end
    end
  end
end
