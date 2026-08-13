# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Represents a Node in the Neo4j graph. Mirrors
      # org.neo4j.driver.types.Node — an Entity with a set of labels.
      class Node < Entity
        attr_reader :labels

        def initialize(id, labels, properties, element_id = nil)
          super(id, properties, element_id)
          @labels = labels
        end
      end
    end
  end
end
