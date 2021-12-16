module Neo4j::Driver
  module Internal
    module Messaging
      module V42
        # Bolt V4.2 is identical to V4.1
        class BoltProtocolV42 < V41::BoltProtocolV41
          VERSION = BoltProtocolVersion.new(4,2)
          INSTANCE = new
        end
      end
    end
  end
end
