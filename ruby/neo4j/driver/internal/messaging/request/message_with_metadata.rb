module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class MessageWithMetadata
          attr_reader :metadata

          def initialize(metadata)
            @metadata = {}
            @metadata = metadata
          end
        end
      end
    end
  end
end
