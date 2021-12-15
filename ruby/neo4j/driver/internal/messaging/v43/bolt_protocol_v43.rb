module Neo4j::Driver
  module Internal
    module Messaging
      module V43
        # Definition of the Bolt Protocol 4.3

        # The version 4.3 use most of the 4.2 behaviours, but it extends it with new messages such as ROUTE
        class BoltProtocolV43
          VERSION = BoltProtocolVersion.new(4,3)
          INSTANCE = new

          def create_message_format
            MessageFormatV43.new
          end
        end
      end
    end
  end
end
