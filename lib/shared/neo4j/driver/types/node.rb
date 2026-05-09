# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Represents a Node in the Neo4j graph
      class Node
        attr_reader :id, :labels, :properties, :element_id

        def initialize(id, labels, properties, element_id = nil)
          @id = id
          @labels = labels
          @properties = properties
          @element_id = element_id || id.to_s
        end

        def [](key)
          @properties[key.to_s] || @properties[key.to_sym]
        end

        def ==(other)
          other.is_a?(Node) && other.id == @id
        end
      end
    end
  end
end
