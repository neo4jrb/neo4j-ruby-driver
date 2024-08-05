module Neo4j::Driver
  module Internal
    module Messaging
      module V5
        class MessageReaderV5 < Common::CommonMessageReader
          def initialize(input)
            super(ValueUnpackerV5.new(input))
          end
        end
      end
    end
  end
end
