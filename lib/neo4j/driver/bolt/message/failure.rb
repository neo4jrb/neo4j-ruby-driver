# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Message
        # Failure response from Neo4j server
        class Failure
          attr_reader :metadata

          def initialize(metadata)
            @metadata = metadata
          end

          def code
            @metadata[:code]
          end

          def message
            @metadata[:message]
          end
        end
      end
    end
  end
end
