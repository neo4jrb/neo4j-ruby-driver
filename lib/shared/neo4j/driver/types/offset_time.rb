# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Bolt OffsetTime — time of day with a fixed UTC offset, stored as
      # nanoseconds-since-midnight (in local wall clock) plus offset
      # seconds. Equivalent to java.time.OffsetTime. Was previously
      # called Types::Time, which collided cosmetically with ::Time.
      class OffsetTime < TemporalValue
        attr_reader :nanoseconds, :tz_offset_seconds

        def self.significant_fields = %i[nanoseconds tz_offset_seconds]

        def initialize(nanoseconds, tz_offset_seconds)
          @nanoseconds = nanoseconds % NANOS_PER_DAY
          @tz_offset_seconds = tz_offset_seconds
        end

        def self.from_nanos(nanoseconds, tz_offset_seconds) = new(nanoseconds, tz_offset_seconds)

        # Accepts "12:34:56.123456789+01:00", "12:34:56Z", or any string
        # containing such a time-with-offset component.
        def self.parse(string)
          match = string.match(/(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?([Z+\-][\d:]*)?/)
          raise ArgumentError, "Invalid OffsetTime format: #{string}" unless match

          nanos = LocalTime.send(:parse_nanos,
                                 match[1].to_i, match[2].to_i, (match[3] || 0).to_i, match[4] || '0')
          new(nanos, parse_offset(match[5] || 'Z'))
        end

        def self.parse_offset(str)
          return 0 if str == 'Z'
          raise ArgumentError, "Invalid timezone offset: #{str}" unless str =~ /^([+\-])(\d{2}):?(\d{2})?$/

          sign = $1 == '+' ? 1 : -1
          sign * ($2.to_i * 3600 + ($3 || 0).to_i * 60)
        end
        private_class_method :parse_offset

        def hour       = (@nanoseconds / NANOS_PER_HOUR) % 24
        def minute     = (@nanoseconds / NANOS_PER_MINUTE) % 60
        def second     = (@nanoseconds / NANOS_PER_SECOND) % 60
        def nanosecond = @nanoseconds % NANOS_PER_SECOND

        # Add a numeric or ActiveSupport::Duration. Sub-second precision
        # preserved (see LocalTime#+).
        def +(seconds)
          self.class.new(@nanoseconds + (seconds.to_f * NANOS_PER_SECOND).round, @tz_offset_seconds)
        end

        def to_s
          # Apply the sign to the formatted offset as a whole, not to
          # `hours` alone — Ruby integer division for `-12600 / 3600` is
          # -4 (floor toward -∞), which would render -03:30 as -04:30.
          abs = @tz_offset_seconds.abs
          sign = @tz_offset_seconds.negative? ? '-' : '+'
          format('%02d:%02d:%02d.%09d%s%02d:%02d',
                 hour, minute, second, nanosecond,
                 sign, abs / 3600, (abs % 3600) / 60)
        end

        # Order by underlying UTC instant. Two OffsetTimes representing
        # the same UTC instant in different offsets compare equal under
        # <=>; == still requires same fields (they're not the same value).
        def <=>(other)
          return nil unless other.is_a?(OffsetTime)
          utc_nanos <=> other.utc_nanos
        end

        protected

        # UTC = local − offset. Positive offset means "ahead of UTC", so
        # the UTC instant is *earlier* (smaller nanos). The previous
        # implementation added instead of subtracting, inverting ordering.
        def utc_nanos
          @nanoseconds - (@tz_offset_seconds * NANOS_PER_SECOND)
        end
      end
    end
  end
end
