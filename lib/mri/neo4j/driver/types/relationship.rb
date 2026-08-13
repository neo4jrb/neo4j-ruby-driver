# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Represents a Relationship in the Neo4j graph.
      # Mirrors Java's org.neo4j.driver.types.Relationship — an Entity with a
      # type and start/end node ids.
      class Relationship < Entity
        attr_reader :start_node_id, :end_node_id, :type,
                    :start_node_element_id, :end_node_element_id

        # Bolt 4.x wire doesn't include start/end_node_element_id —
        # PackStream hydration passes nil for those slots. Fall back to
        # the stringified node id so callers always see a value
        # (matches what Java's driver does for 4.x). Path-bound
        # relationships pass the actual node element_ids from #bind,
        # which override the fallback.
        def initialize(id, start_node_id, end_node_id, type, properties,
                       element_id = nil, start_node_element_id = nil,
                       end_node_element_id = nil)
          super(id, properties, element_id)
          @start_node_id = start_node_id
          @end_node_id = end_node_id
          @type = type
          @start_node_element_id = start_node_element_id || start_node_id.to_s
          @end_node_element_id = end_node_element_id || end_node_id.to_s
        end
      end
    end
  end
end
