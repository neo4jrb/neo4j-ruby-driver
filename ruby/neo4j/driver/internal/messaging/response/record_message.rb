module Neo4j::Driver
  module Internal
    module Messaging
      module Response
        class RecordMessage < Struct.new(:fields)
          SIGNATURE = 0x71
        end
      end
    end
  end
end
