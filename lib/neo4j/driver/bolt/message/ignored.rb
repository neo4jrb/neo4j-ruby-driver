# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Message
        # Ignored response from Neo4j server (previous request was ignored)
        class Ignored
          def initialize(metadata = {})
            @metadata = metadata
          end
        end
      end
    end
  end
end
