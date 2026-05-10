# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Bolt LocalTime — time of day without timezone, stored as
      # nanoseconds since midnight.
      class LocalTime < TemporalValue
        attr_reader :nanoseconds

        def self.significant_fields = %i[nanoseconds]

        def initialize(nanoseconds)
          @nanoseconds = nanoseconds % NANOS_PER_DAY
        end

        def self.from_nanos(nanoseconds) = new(nanoseconds)

        # Accepts "12:34:56.123456789" or any string containing such a
        # time component (so a full datetime works too — we just take the
        # time fields).
        def self.parse(string)
          match = string.match(/(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?/)
          raise ArgumentError, "Invalid LocalTime format: #{string}" unless match

          new(parse_nanos(match[1].to_i, match[2].to_i, (match[3] || 0).to_i, match[4] || '0'))
        end

        def self.parse_nanos(hour, minute, second, fraction)
          hour * NANOS_PER_HOUR +
            minute * NANOS_PER_MINUTE +
            second * NANOS_PER_SECOND +
            fraction.ljust(9, '0')[0..8].to_i
        end
        private_class_method :parse_nanos

        def hour       = (@nanoseconds / NANOS_PER_HOUR) % 24
        def minute     = (@nanoseconds / NANOS_PER_MINUTE) % 60
        def second     = (@nanoseconds / NANOS_PER_SECOND) % 60
        def nanosecond = @nanoseconds % NANOS_PER_SECOND

        # Add a numeric or ActiveSupport::Duration. Sub-second precision
        # preserved by going through to_f (NOT to_i, which dropped 0.5s).
        def +(seconds)
          self.class.new(@nanoseconds + (seconds.to_f * NANOS_PER_SECOND).round)
        end

        def to_s
          format('%02d:%02d:%02d.%09d', hour, minute, second, nanosecond)
        end
      end
    end
  end
end
