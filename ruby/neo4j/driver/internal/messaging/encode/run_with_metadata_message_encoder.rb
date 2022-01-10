module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class RunWithMetadataMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::RunWithMetadataMessage)
            packer.pack_struct_header(3, message.signature)
            packer.pack(message.query)
            packer.pack(message.parameters)
            packer.pack(message.metadata)
          end
        end
      end
    end
  end
end
