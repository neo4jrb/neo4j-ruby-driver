module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class InitMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::InitMessage)
            packer.pack_struct_header(2, message.signature)
            packer.pack(message.user_agent)
            packer.pack(message.auth_token)
          end
        end
      end
    end
  end
end
