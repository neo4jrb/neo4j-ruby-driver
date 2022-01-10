module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class DiscardMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::DiscardMessage)
            packer.pack_struct_header(1, Request::DiscardMessage::SIGNATURE)
            packer.pack(message.metadata)
          end
        end
      end
    end
  end
end
