module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class DiscardAllMessage
          SIGNATURE = 0x2F
          DISCARD_ALL = new

          def to_s
            "DISCARD_ALL"
          end
        end
      end
    end
  end
end
