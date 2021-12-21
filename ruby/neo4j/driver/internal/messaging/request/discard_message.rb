module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class DiscardMessage < AbstractStreamingMessage
          SIGNATURE = 0x2F

          def initialize(n, id)
            super(n, id)
          end

          def self.new_discard_all_message(id)
            new(STREAM_LIMIT_UNLIMITED, id)
          end

          def name
            "DISCARD"
          end
        end
      end
    end
  end
end
