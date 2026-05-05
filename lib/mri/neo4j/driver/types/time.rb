# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Time with timezone offset - Neo4j Time type (time of day with timezone)
      # Wraps nanoseconds since midnight and timezone offset
      class Time
        include Comparable

        attr_reader :nanoseconds, :tz_offset_seconds

        NANOS_PER_DAY = 86_400_000_000_000

        def initialize(nanoseconds, tz_offset_seconds)
          @nanoseconds = nanoseconds % NANOS_PER_DAY
          @tz_offset_seconds = tz_offset_seconds
        end

        def self.from_nanos(nanoseconds, tz_offset_seconds)
          new(nanoseconds, tz_offset_seconds)
        end

        def self.parse(string)
          # Parse time string like "12:34:56.123456789+01:00", "12:34:56Z", or "2018-1-1 8:00Z" (extracts time part)
          # Extract time portion if datetime format
          time_match = string.match(/(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?([Z+\-][\d:]*)?/)
          raise ArgumentError, "Invalid Time format: #{string}" unless time_match

          hour = time_match[1].to_i
          minute = time_match[2].to_i
          second = (time_match[3] || 0).to_i
          fraction = time_match[4] || '0'
          offset_str = time_match[5] || 'Z'

          # Pad or truncate fraction to 9 digits (nanoseconds)
          nanos_from_fraction = fraction.ljust(9, '0')[0..8].to_i

          total_nanos = hour * 3_600_000_000_000 +
                       minute * 60_000_000_000 +
                       second * 1_000_000_000 +
                       nanos_from_fraction

          # Parse offset
          tz_offset_seconds = if offset_str == 'Z'
            0
          elsif offset_str =~ /^([+\-])(\d{2}):?(\d{2})?$/
            sign = $1 == '+' ? 1 : -1
            hours = $2.to_i
            mins = ($3 || 0).to_i
            sign * (hours * 3600 + mins * 60)
          else
            raise ArgumentError, "Invalid timezone offset: #{offset_str}"
          end

          new(total_nanos, tz_offset_seconds)
        end

        def hour
          (@nanoseconds / 3_600_000_000_000) % 24
        end

        def minute
          (@nanoseconds / 60_000_000_000) % 60
        end

        def second
          (@nanoseconds / 1_000_000_000) % 60
        end

        def nanosecond
          @nanoseconds % 1_000_000_000
        end

        # Compare times by their UTC instant (nanoseconds adjusted for timezone)
        def <=>(other)
          return nil unless other.is_a?(Time)
          utc_nanos <=> other.utc_nanos
        end

        def ==(other)
          other.is_a?(Time) &&
            @nanoseconds == other.nanoseconds &&
            @tz_offset_seconds == other.tz_offset_seconds
        end

        alias eql? ==

        def hash
          [@nanoseconds, @tz_offset_seconds].hash
        end

        def +(seconds)
          # Handle ActiveSupport::Duration or numeric seconds
          seconds_to_add = seconds.respond_to?(:to_i) ? seconds.to_i : seconds
          nanos_to_add = seconds_to_add * 1_000_000_000
          Time.new(@nanoseconds + nanos_to_add, @tz_offset_seconds)
        end

        def to_s
          offset_hours = @tz_offset_seconds / 3600
          offset_mins = (@tz_offset_seconds % 3600) / 60
          format('%02d:%02d:%02d.%09d%+03d:%02d', hour, minute, second, nanosecond, offset_hours, offset_mins)
        end

        protected

        # Get nanoseconds in UTC (for comparison purposes)
        # In Neo4j's representation, offset indicates how far ahead/behind UTC the time zone is
        def utc_nanos
          @nanoseconds + (@tz_offset_seconds * 1_000_000_000)
        end
      end
    end
  end
end
