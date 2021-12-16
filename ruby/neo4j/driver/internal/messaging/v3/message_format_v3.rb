module Neo4j::Driver
  module Internal
    module Messaging
      module V3
        class MessageFormatV3
          def new_writer(output)
            MessageWriterV3.new(output)
          end

          def new_reader(input)
            Common::CommonMessageReader.new(input)
          end
        end
      end
    end
  end
end
