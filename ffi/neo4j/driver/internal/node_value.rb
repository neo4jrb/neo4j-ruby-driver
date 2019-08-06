# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module NodeValue
        CODE = :N
        extend StructureValue

        def self.to_ruby_value(id, labels, properties)
          Types::Node.new(id, labels, properties)
        end
      end
    end
  end
end
