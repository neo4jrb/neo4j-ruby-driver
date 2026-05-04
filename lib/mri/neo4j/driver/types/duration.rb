# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Duration
      # Neo4j stores durations as months, days, seconds, and nanoseconds
      # All values must be integers (matching Neo4j's Bolt protocol and Java driver)
      class Duration
        attr_reader :months, :days, :seconds, :nanoseconds

        NANOS_PER_SECOND = 1_000_000_000

        def initialize(months, days, seconds, nanoseconds)
          @months = months.to_i
          @days = days.to_i
          @seconds = seconds.to_i
          @nanoseconds = nanoseconds.to_i
          normalize!
        end

        # Parse ISO 8601 duration format
        # Examples: "P1Y2M3DT4H5M6.789S", "P3M", "PT2H30M"
        def self.parse(string)
          unless string =~ /^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$/
            raise ArgumentError, "Invalid ISO 8601 duration format: #{string}"
          end

          years = ($1 || 0).to_i
          months = ($2 || 0).to_i
          days = ($3 || 0).to_i
          hours = ($4 || 0).to_i
          minutes = ($5 || 0).to_i
          seconds_with_fraction = ($6 || 0).to_f

          total_months = years * 12 + months
          whole_seconds = seconds_with_fraction.to_i
          fractional_seconds = seconds_with_fraction - whole_seconds
          nanos = (fractional_seconds * NANOS_PER_SECOND).round
          total_seconds = hours * 3600 + minutes * 60 + whole_seconds

          new(total_months, days, total_seconds, nanos)
        end

        def ==(other)
          return false unless other.is_a?(Duration)
          @months == other.months &&
            @days == other.days &&
            @seconds == other.seconds &&
            @nanoseconds == other.nanoseconds
        end

        def parts
          {
            months: @months,
            days: @days,
            seconds: @seconds,
            nanoseconds: @nanoseconds
          }
        end

        def to_s
          "P#{@months}M#{@days}DT#{@seconds}.#{@nanoseconds}S"
        end

        private

        # Normalize nanoseconds overflow/underflow into seconds
        # e.g., -1ns becomes -1s + 999999999ns
        # e.g., 1_500_000_000ns becomes 1s + 500_000_000ns
        def normalize!
          if @nanoseconds < 0
            # Move negative nanoseconds into seconds
            sec_adjust = (@nanoseconds.abs / NANOS_PER_SECOND.to_f).ceil
            @seconds -= sec_adjust
            @nanoseconds += sec_adjust * NANOS_PER_SECOND
          elsif @nanoseconds >= NANOS_PER_SECOND
            # Move excess nanoseconds into seconds
            sec_adjust = @nanoseconds / NANOS_PER_SECOND
            @seconds += sec_adjust
            @nanoseconds %= NANOS_PER_SECOND
          end
        end
      end
    end
  end
end
