# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module OffsetTimeValue
        CODE = :T
        extend StructureValue
        extend BaseTimeValue

        class << self
          def to_ruby_value(nano_of_day_local, offset_seconds)
            Types::OffsetTime.new(time(nano_of_day_local, offset_seconds))
          end

          def to_neo_values(offset_time)
            [super, offset_time.utc_offset]
          end
        end
      end
    end
  end
end
