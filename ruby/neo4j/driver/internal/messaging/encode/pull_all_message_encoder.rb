module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class PullAllMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::PullAllMessage)
            packer.pack_struct_header(0, Request::PullAllMessage::SIGNATURE)
          end
        end
      end
    end
  end
end
