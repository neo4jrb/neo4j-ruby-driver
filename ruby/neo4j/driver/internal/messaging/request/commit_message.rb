module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class CommitMessage
          SIGNATURE = 0x12
          COMMIT = new

          def signature
            SIGNATURE
          end

          def to_s
            "COMMIT"
          end
        end
      end
    end
  end
end
