module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        # PULL request message
        # <p>
        # Sent by clients to pull the entirety of the remaining stream down.
        class PullMessage < AbstractStreamingMessage
          SIGNATURE = 0x3F

          def name
            "PULL"
          end

          def signature
            SIGNATURE
          end
        end
      end
    end
  end
end
