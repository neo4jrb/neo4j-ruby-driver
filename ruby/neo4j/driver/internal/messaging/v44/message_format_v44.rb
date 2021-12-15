module Neo4j::Driver
  module Internal
    module Messaging
      module V44
        # Bolt message format v4.4
        class MessageFormatV44
          def new_writer(output)
            MessageWriterV44.new(output)
          end

          def new_reader(input)
            CommonMessageReader.new(input)
          end
        end
      end
    end
  end
end
