# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Value
        module RelationshipValue
          CODE = :R
          extend StructureValue

          def self.to_ruby_value(id, start_node_id, end_node_id, type, properties)
            Types::Relationship.new(id, start_node_id, end_node_id, type, properties)
          end
        end
      end
    end
  end
end
