# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module NodeValue
        extend StructureValue

        class << self
          def code_sym
            :N
          end

          def to_ruby_value(id, labels, properties)
            Neo4j::Driver::Types::Node.new(id, labels, properties)
          end
        end
      end
    end
  end
end
