module Neo4j::Driver
  module Internal
    module Messaging
      module V5
        # Bolt message format v5.0
        class MessageFormatV5 < V44::MessageFormatV44
          def new_writer(output)
            output.date_time_utc_enabled = true
            super
          end
          def new_value_unpacker(input)
            ValueUnpackerV5.new(input)
          end
        end
      end
    end
  end
end
