module Neo4j::Driver
  module Internal
    module Messaging
      module V4
        class MessageFormatV4 < V3::MessageFormatV3
          def new_writer(output)
            MessageWriterV4.new(output)
          end
        end
      end
    end
  end
end
