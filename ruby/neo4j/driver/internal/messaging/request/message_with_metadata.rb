module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class MessageWithMetadata < Struct.new(:metadata)
        end
      end
    end
  end
end
