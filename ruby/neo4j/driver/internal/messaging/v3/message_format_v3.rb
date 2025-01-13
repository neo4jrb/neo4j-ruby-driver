module Neo4j::Driver
  module Internal
    module Messaging
      module V3
        class MessageFormatV3
          def new_writer(output)
            MessageWriterV3.new(output)
          end

          def new_reader(input) = Common::CommonMessageReader.new(new_value_unpacker(input))

          def new_value_unpacker(input) = Async::Connection::StreamReader.new(input)
        end
      end
    end
  end
end
