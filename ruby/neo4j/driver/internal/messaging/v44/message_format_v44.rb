module Neo4j::Driver
  module Internal
    module Messaging
      module V44
        # Bolt message format v4.4
        class MessageFormatV44 < V43::MessageFormatV43
          def new_writer(output)
            MessageWriterV44.new(output)
          end
        end
      end
    end
  end
end
