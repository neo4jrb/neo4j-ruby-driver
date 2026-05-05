# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Bolt Duration. Stores months, days, seconds, nanoseconds as
      # distinct ints — Neo4j keeps these separate because months are
      # variable-length (no fixed conversion to seconds).
      class Duration < TemporalValue
        attr_reader :months, :days, :seconds, :nanoseconds

        def self.significant_fields = %i[months days seconds nanoseconds]

        def initialize(months, days, seconds, nanoseconds)
          @months = months.to_i
          @days = days.to_i
          @seconds = seconds.to_i
          @nanoseconds = nanoseconds.to_i
          normalize!
        end

        # Parse ISO 8601 duration: "P1Y2M3DT4H5M6.789S", "P3M", "PT2H30M"
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

        def parts
          { months: @months, days: @days, seconds: @seconds, nanoseconds: @nanoseconds }
        end

        # ISO 8601 form. Nanoseconds get a 9-digit zero-padded suffix on
        # seconds so 1s + 5ns prints as "PT1.000000005S", not "PT1.5S".
        def to_s
          if @nanoseconds.zero?
            format('P%dM%dDT%dS', @months, @days, @seconds)
          else
            format('P%dM%dDT%d.%09dS', @months, @days, @seconds, @nanoseconds)
          end
        end

        private

        # Normalize nanoseconds overflow/underflow into seconds:
        # -1ns becomes -1s + 999999999ns; 1.5e9 ns becomes 1s + 5e8 ns.
        def normalize!
          if @nanoseconds < 0
            sec_adjust = (@nanoseconds.abs / NANOS_PER_SECOND.to_f).ceil
            @seconds -= sec_adjust
            @nanoseconds += sec_adjust * NANOS_PER_SECOND
          elsif @nanoseconds >= NANOS_PER_SECOND
            sec_adjust = @nanoseconds / NANOS_PER_SECOND
            @seconds += sec_adjust
            @nanoseconds %= NANOS_PER_SECOND
          end
        end
      end
    end
  end
end
