# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module RelationshipValue
        extend StructureValue

        class << self
          def code_sym
            :R
          end

          def to_ruby_value(id, start_node_id, end_node_id, type, properties)
            Neo4j::Driver::Types::Relationship.new(id, start_node_id, end_node_id, type, properties)
          end
        end
      end
    end
  end
end
