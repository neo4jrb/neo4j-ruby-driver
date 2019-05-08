# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module DateValue
        extend StructureValue
        EPOCH = Date.parse('1970-01-01')

        class << self
          def code_sym
            :D
          end

          def to_ruby_value(epoch_day)
            EPOCH + epoch_day
          end

          def to_neo_values(date)
            (date - EPOCH).to_i
          end
        end
      end
    end
  end
end
