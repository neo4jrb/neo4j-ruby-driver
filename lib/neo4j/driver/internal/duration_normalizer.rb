# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module DurationNormalizer
        class << self
          def normalize(object)
            parts = object.parts.to_h
            parts.default = 0
            months_i, months_remainder_seconds = divmod(months(parts), ActiveSupport::Duration::SECONDS_PER_MONTH)
            months_days, months_remainder_seconds =
              months_remainder_seconds.divmod(ActiveSupport::Duration::SECONDS_PER_DAY)
            days_i, days_remainder_seconds = divmod(months_days + days(parts), ActiveSupport::Duration::SECONDS_PER_DAY)
            seconds_i, nonanoseconds = divmod(months_remainder_seconds + days_remainder_seconds + seconds(parts),
                                              1_000_000_000)
            [months_i, days_i, seconds_i, nonanoseconds.round]
          end

          def milliseconds(duration)
            duration&.in_milliseconds&.round
          end

          def create(months, days, seconds, nanoseconds)
            { months:, days:, seconds: seconds + (nanoseconds.zero? ? 0 : nanoseconds * BigDecimal('1e-9')) }
              .sum { |key, value| ActiveSupport::Duration.send(key, value) }
          end

          private

          def divmod(number, factor)
            number_i, remainder = number.divmod(1)
            [number_i.to_i, remainder * factor]
          end

          def months(parts)
            parts[:years] * 12 + parts[:months]
          end

          def days(parts)
            parts[:weeks] * 7 + parts[:days]
          end

          def seconds(parts)
            parts[:hours] * ActiveSupport::Duration::SECONDS_PER_HOUR +
              parts[:minutes] * ActiveSupport::Duration::SECONDS_PER_MINUTE + parts[:seconds]
          end
        end
      end
    end
  end
end
