# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class Relationship < Entity
        attr_reader :start_node_id, :end_node_id, :type

        def initialize(id, start_node_id, end_node_id, type, properties)
          super(id, properties)
          @start_node_id = start_node_id
          @end_node_id = end_node_id
          @type = type
        end
      end
    end
  end
end
