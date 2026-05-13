# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Represents an unbound relationship (used in paths before binding to nodes)
      class UnboundRelationship
        attr_reader :id, :type, :properties, :element_id

        def initialize(id, type, properties, element_id = nil)
          @id = id
          @type = type
          @properties = properties
          @element_id = element_id || id.to_s
        end

        def [](key)
          @properties[key.to_s] || @properties[key.to_sym]
        end

        # Bind this relationship to specific start and end nodes
        def bind(start_node_id, end_node_id, start_node_element_id = nil, end_node_element_id = nil)
          Relationship.new(@id, start_node_id, end_node_id, @type, @properties,
                           @element_id, start_node_element_id, end_node_element_id)
        end
      end
    end
  end
end
