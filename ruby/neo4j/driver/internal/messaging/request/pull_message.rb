module Neo4j::Driver
  module Internal
    module Messaging
      module Request

        # PULL request message
        # <p>
        # Sent by clients to pull the entirety of the remaining stream down.
        class PullMessage < AbstractStreamingMessage
          SIGNATURE = 0x3F
          PULL_ALL = new(STREAM_LIMIT_UNLIMITED, -1)

          def initialize(n, id)
            super(n, id)
          end

          def name
            "PULL"
          end
        end
      end
    end
  end
end
