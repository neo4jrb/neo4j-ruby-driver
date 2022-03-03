module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class BeginMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::BeginMessage)
            packer.pack_struct_header(1, message.signature)
            packer.pack(message.metadata)
          end
        end
      end
    end
  end
end
