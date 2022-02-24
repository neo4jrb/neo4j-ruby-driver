module Neo4j::Driver
  module Internal
    class InternalIsoDuration < Struct.new(:months, :days, :seconds, :nanoseconds)
      NANOS_PER_SECOND = 1_000_000_000
      SUPPORTED_UNITS = [java.time.temporal.ChronoUnit::DAYS, java.time.temporal.ChronoUnit::MONTHS, java.time.temporal.ChronoUnit::NANOS, java.time.temporal.ChronoUnit::SECONDS].freeze

      def get(unit)
        case unit
        when java.time.temporal.ChronoUnit::MONTHS
          months
        when java.time.temporal.ChronoUnit::DAYS
          days
        when java.time.temporal.ChronoUnit::SECONDS
          seconds
        when java.time.temporal.ChronoUnit::NANOS
          nanoseconds
        else
          raise java.time.temporal.UnsupportedTemporalTypeException, "Unsupported unit: #{unit}"
        end
      end

      def add_to(temporal)
        temporal = temporal.plus(months, java.time.temporal.ChronoUnit::MONTHS) if months != 0

        temporal = temporal.plus(days, java.time.temporal.ChronoUnit::DAYS) if days != 0

        temporal = temporal.plus(seconds, java.time.temporal.ChronoUnit::SECONDS) if seconds != 0

        temporal = temporal.plus(nanoseconds, java.time.temporal.ChronoUnit::NANOS) if nanoseconds != 0

        temporal
      end

      def subtract_from(temporal)
        temporal = temporal.minus(months, java.time.temporal.ChronoUnit::MONTHS) if months != 0

        temporal = temporal.minus(days, java.time.temporal.ChronoUnit::DAYS) if days != 0

        temporal = temporal.minus(seconds, java.time.temporal.ChronoUnit::SECONDS) if seconds != 0

        temporal = temporal.minus(nanoseconds, java.time.temporal.ChronoUnit::NANOS) if nanoseconds != 0

        temporal
      end
    end
  end
end
