# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class Node < Entity
        attr_reader :labels

        def initialize(id, labels, properties)
          super(id, properties)
          @labels = labels
        end
      end
    end
  end
end
