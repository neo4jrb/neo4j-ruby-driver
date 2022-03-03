module Neo4j::Driver
  module Internal
    module Messaging
      module V43
        # Bolt message format v4.3
        class MessageFormatV43
          def new_writer(output)
            MessageWriterV43.new(output)
          end

          def new_reader(input)
            Common::CommonMessageReader.new(input)
          end
        end
      end
    end
  end
end
