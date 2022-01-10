module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class RunMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::RunMessage)
            packer.pack_struct_header(2, message.signature)
            packer.pack(message.query)
            packer.pack(message.parameters)
          end
        end
      end
    end
  end
end
