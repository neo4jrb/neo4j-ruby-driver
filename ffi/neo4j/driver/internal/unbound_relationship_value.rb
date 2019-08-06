# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module UnboundRelationshipValue
        CODE = :r
        extend StructureValue

        def self.to_ruby_value(id, type, properties)
          Types::Relationship.new(id, nil, nil, type, properties)
        end
      end
    end
  end
end
