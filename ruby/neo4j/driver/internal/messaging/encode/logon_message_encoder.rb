module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class LogonMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::LogonMessage)
            packer.pack_struct_header(1, message.class::SIGNATURE)
            packer.pack(message.metadata)
          end
        end
      end
    end
  end
end
