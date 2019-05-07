# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module DateValue
        extend StructureValue

        EPOCH = Date.parse('1970-01-01')

        class << self
          def to_ruby(value)
            EPOCH + Neo4j::Driver::Value.to_ruby(Bolt::Structure.value(value, 0))
          end

          def to_neo(value, object)
            Bolt::Value.format_as_structure(value, code, 1)
            Neo4j::Driver::Value.to_neo(Bolt::Structure.value(value, 0), (object - EPOCH).to_i)
          end

          private

          def code_sym
            :D
          end
        end
      end
    end
  end
end
