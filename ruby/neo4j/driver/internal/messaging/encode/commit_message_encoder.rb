module Neo4j::Driver
  module Internal
    module Messaging
      module Encode
        class CommitMessageEncoder
          def encode(message, packer)
            Util::Preconditions.check_argument(message, Request::CommitMessage)
            packer.pack_struct_header(0, Request::CommitMessage::SIGNATURE)
          end
        end
      end
    end
  end
end
