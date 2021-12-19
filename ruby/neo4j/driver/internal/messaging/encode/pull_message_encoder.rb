module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class PullMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::PullMessage)
            packer.pack_struct_header(1, Request::PullMessage::SIGNATURE)
            packer.pack(messag.metadata)
          end
        end
      end
    end
  end
end
