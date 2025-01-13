module Neo4j::Driver
  module Internal
    module Messaging
      module V51
        # Bolt message format v4.4
        class MessageFormatV51 < V5::MessageFormatV5
          def new_writer(output)
            MessageWriterV51.new(output)
          end
        end
      end
    end
  end
end
