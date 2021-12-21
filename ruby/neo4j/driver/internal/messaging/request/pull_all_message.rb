module Neo4j::Driver
  module Internal
    module Messaging
      module Request

        # PULL_ALL request message
        # <p>
        # Sent by clients to pull the entirety of the remaining stream down.
        class PullAllMessage
          SIGNATURE = 0x3F
          PULL_ALL = new

          def to_s
            'PULL_ALL'
          end
        end
      end
    end
  end
end
