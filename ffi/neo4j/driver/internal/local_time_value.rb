# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module LocalTimeValue
        CODE = :t
        extend StructureValue
        extend BaseTimeValue

        def self.to_ruby_value(nano_of_day_local)
          Neo4j::Driver::Types::LocalTime.new(time(nano_of_day_local))
        end
      end
    end
  end
end
