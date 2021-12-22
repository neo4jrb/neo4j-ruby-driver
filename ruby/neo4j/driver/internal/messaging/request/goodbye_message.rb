module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class GoodbyeMessage
          SIGNATURE = 0x02
          GOODBYE = new

          def signature
            SIGNATURE
          end

          def to_s
            "GOODBYE"
          end
        end
      end
    end
  end
end
