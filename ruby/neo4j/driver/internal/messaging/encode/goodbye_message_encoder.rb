module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class GoodbyeMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::GoodbyeMessage)
            packer.pack_struct_header(0, Request::GoodbyeMessage::SIGNATURE)
          end
        end
      end
    end
  end
end
