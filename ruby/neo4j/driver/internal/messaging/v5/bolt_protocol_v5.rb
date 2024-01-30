module Neo4j::Driver
  module Internal
    module Messaging
      module V5
        # Definition of the Bolt Protocol 4.4
        class BoltProtocolV5 < V44::BoltProtocolV44
          VERSION = BoltProtocolVersion.new(5,0)
          INSTANCE = new

          def create_message_format
            MessageFormatV5.new
          end

          def include_date_time_utc_patch_in_hello
            false
          end
        end
      end
    end
  end
end
