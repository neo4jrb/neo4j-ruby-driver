module Neo4j::Driver
  module Internal
    module Messaging
      module V44
        # Definition of the Bolt Protocol 4.4
        class BoltProtocolV44 < V43::BoltProtocolV43
          VERSION = BoltProtocolVersion.new(4,4)
          INSTANCE = new

          def create_message_format
            MessageFormatV44.new
          end
        end
      end
    end
  end
end
