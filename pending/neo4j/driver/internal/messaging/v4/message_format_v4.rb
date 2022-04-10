module Neo4j::Driver
  module Internal
    module Messaging
      module V4
        class MessageFormatV4
          def new_writer(output)
            MessageWriterV4.new(output)
          end

          def new_reader(input)
            Common::CommonMessageReader.new(input)
          end
        end
      end
    end
  end
end
