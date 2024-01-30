module Neo4j::Driver
  module Internal
    module Messaging
      module V5
        # Bolt message format v4.4
        class MessageFormatV5
          def new_writer(output)
            MessageWriterV5.new(output)
          end

          def new_reader(input)
            MessageReaderV5.new(input)
          end
        end
      end
    end
  end
end
