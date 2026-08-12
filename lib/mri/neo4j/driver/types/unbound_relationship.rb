# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Represents an unbound relationship (used in paths before binding to
      # nodes). An Entity with a type but no start/end nodes yet.
      class UnboundRelationship < Entity
        attr_reader :type

        def initialize(id, type, properties, element_id = nil)
          super(id, properties, element_id)
          @type = type
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
