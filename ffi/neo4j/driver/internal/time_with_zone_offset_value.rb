# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module TimeWithZoneOffsetValue
        CODE = :F
        extend StructureValue

        class << self
          def to_ruby_value(epoch_second_local, nsec, offset)
            time = Time.at(epoch_second_local, nsec, :nsec).utc
            Time.new(time.year, time.month, time.mday, time.hour, time.min, time.sec + Rational(nsec, 1_000_000_000),
                     offset)
            # In ruby 2.6.x
            # Time.at(sec, nsec, :nsec, tz: offset)
          end

          def to_neo_values(time)
            [time.to_i + time.utc_offset, time.nsec, time.utc_offset]
          end
        end
      end
    end
  end
end
