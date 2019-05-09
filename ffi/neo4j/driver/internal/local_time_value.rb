# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module LocalTimeValue
        extend StructureValue
        extend BaseTimeValue

        class << self
          def code_sym
            :t
          end

          def to_ruby_value(nano_of_day_local)
            Neo4j::Driver::Types::LocalTime.new(time(nano_of_day_local))
          end
        end
      end
    end
  end
end
