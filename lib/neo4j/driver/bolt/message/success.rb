# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Message
        # Success response from Neo4j server
        class Success
          attr_reader :metadata

          def initialize(metadata = {})
            @metadata = metadata
          end
        end
      end
    end
  end
end
