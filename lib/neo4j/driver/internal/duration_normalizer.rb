# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module DurationNormalizer
        class << self
          def normalize(object)
            parts = object.parts
            months = parts[:years] * 12 + parts[:months]
            months_i = months.to_i
            months_remainder_seconds = (months - months_i) * ActiveSupport::Duration::SECONDS_PER_MONTH
            months_days = months_remainder_seconds / ActiveSupport::Duration::SECONDS_PER_DAY
            months_days_i = months_days.to_i
            months_remainder_seconds -= months_days_i * ActiveSupport::Duration::SECONDS_PER_DAY
            days = months_days_i + parts[:weeks] * 7 + parts[:days]
            days_i = days.to_i
            days_remainder_seconds = (days - days_i) * ActiveSupport::Duration::SECONDS_PER_DAY
            seconds = months_remainder_seconds + days_remainder_seconds +
              parts[:hours] * ActiveSupport::Duration::SECONDS_PER_HOUR +
              parts[:minutes] * ActiveSupport::Duration::SECONDS_PER_MINUTE +
              parts[:seconds]
            seconds_i = seconds.to_i
            nanoseconds_i = ((seconds - seconds_i) * 1e9).round
            [months_i, days_i, seconds_i, nanoseconds_i]
          end
        end
      end
    end
  end
end
