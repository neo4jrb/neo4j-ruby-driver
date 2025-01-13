module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class LogoffMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::LogoffMessage)
            packer.pack_struct_header(0, message.class::SIGNATURE)
          end
        end
      end
    end
  end
end
