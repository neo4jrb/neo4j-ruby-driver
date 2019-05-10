# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module BaseTimeValue
        NANO_FACTOR = 1_000_000_000

        def time(nano_of_day_local, offset_seconds = nil)
          min, sec = Rational(nano_of_day_local, NANO_FACTOR).divmod(60)
          Time.new(0, 1, 1, *min.divmod(60), sec, offset_seconds)
        end

        def to_neo_values(local_time)
          ((local_time.hour * 60 + local_time.min) * 60 + local_time.sec) * NANO_FACTOR + local_time.nsec
        end
      end
    end
  end
end
