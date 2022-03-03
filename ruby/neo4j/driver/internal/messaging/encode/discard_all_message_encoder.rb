module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class DiscardAllMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::DiscardAllMessage)
            packer.pack_struct_header(0, Request::DiscardAllMessage::SIGNATURE)
          end
        end
      end
    end
  end
end
