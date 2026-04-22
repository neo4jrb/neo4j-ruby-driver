# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # LocalTime (time of day without timezone)
      class LocalTime
        include Comparable

        attr_reader :nanoseconds

        NANOS_PER_DAY = 86_400_000_000_000

        def initialize(nanoseconds)
          @nanoseconds = nanoseconds % NANOS_PER_DAY
        end

        def self.from_nanos(nanoseconds)
          new(nanoseconds)
        end

        def self.parse(string)
          # Parse time string like "12:34:56.123456789" or "2018-1-1 8:00" (extracts time part)
          # Extract time portion if datetime format
          time_string = string.match(/(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?/)
          raise ArgumentError, "Invalid LocalTime format: #{string}" unless time_string

          hour = time_string[1].to_i
          minute = time_string[2].to_i
          second = (time_string[3] || 0).to_i
          fraction = time_string[4] || '0'

          # Pad or truncate fraction to 9 digits (nanoseconds)
          nanos_from_fraction = fraction.ljust(9, '0')[0..8].to_i

          total_nanos = hour * 3_600_000_000_000 +
                       minute * 60_000_000_000 +
                       second * 1_000_000_000 +
                       nanos_from_fraction

          new(total_nanos)
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

        def <=>(other)
          return nil unless other.is_a?(LocalTime)
          @nanoseconds <=> other.nanoseconds
        end

        def ==(other)
          other.is_a?(LocalTime) && @nanoseconds == other.nanoseconds
        end

        alias eql? ==

        def hash
          @nanoseconds.hash
        end

        def +(seconds)
          # Handle ActiveSupport::Duration or numeric seconds
          seconds_to_add = seconds.respond_to?(:to_i) ? seconds.to_i : seconds
          nanos_to_add = seconds_to_add * 1_000_000_000
          LocalTime.new(@nanoseconds + nanos_to_add)
        end

        def to_s
          format('%02d:%02d:%02d.%09d', hour, minute, second, nanosecond)
        end
      end
    end
  end
end
