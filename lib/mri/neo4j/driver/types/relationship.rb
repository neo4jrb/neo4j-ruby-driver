# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Represents a Relationship in the Neo4j graph
      class Relationship
        attr_reader :id, :start_node_id, :end_node_id, :type, :properties, :element_id

        def initialize(id, start_node_id, end_node_id, type, properties, element_id = nil)
          @id = id
          @start_node_id = start_node_id
          @end_node_id = end_node_id
          @type = type
          @properties = properties
          @element_id = element_id || id.to_s
        end

        def [](key)
          @properties[key.to_s] || @properties[key.to_sym]
        end

        def ==(other)
          other.is_a?(Relationship) && other.id == @id
        end
      end
    end
  end
end
