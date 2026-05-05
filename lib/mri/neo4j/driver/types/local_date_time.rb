# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Bolt LocalDateTime — wall-clock datetime without timezone.
      # Stored as the wire-format pair (epoch_seconds, nanoseconds), where
      # epoch_seconds is the wall-clock components encoded as if they were
      # UTC. Two LocalDateTimes representing the same wall-clock value
      # always have the same field values regardless of the host TZ.
      class LocalDateTime < TemporalValue
        PARSE_FORMATS = [
          '%Y-%m-%d %H:%M:%S.%N',
          '%Y-%m-%dT%H:%M:%S.%N',
          '%Y-%m-%d %H:%M:%S',
          '%Y-%m-%dT%H:%M:%S',
          '%Y-%m-%d %H:%M'
        ].freeze

        attr_reader :epoch_seconds, :nanoseconds

        def self.significant_fields = %i[epoch_seconds nanoseconds]

        def initialize(epoch_seconds, nanoseconds)
          @epoch_seconds = epoch_seconds
          @nanoseconds = nanoseconds
        end

        def self.from_epoch(epoch_seconds, nanoseconds) = new(epoch_seconds, nanoseconds)

        def self.from_time(time)
          new(time.to_i, ((time.to_f - time.to_i) * NANOS_PER_SECOND).round)
        end

        def self.parse(string)
          # Strip trailing timezone if present — naive datetime ignores it.
          naive = string.sub(/[Z+\-]\d{2}:?\d{2}?$/, '')
          time = PARSE_FORMATS.lazy.filter_map { |fmt| ::Time.strptime(naive, fmt) rescue nil }.first
          raise ArgumentError, "Invalid LocalDateTime format: #{string}" unless time
          from_time(::Time.utc(*time_components(time)))
        end

        def self.time_components(time)
          [time.year, time.month, time.day, time.hour, time.min, time.sec, time.subsec * 1_000_000]
        end
        private_class_method :time_components

        def to_time
          ::Time.at(@epoch_seconds, @nanoseconds.to_i, :nanosecond)
        end

        # Add a numeric or ActiveSupport::Duration. Sub-second precision
        # preserved by going through to_f.
        def +(seconds)
          self.class.from_time(to_time + seconds.to_f)
        end

        def to_s
          to_time.strftime('%Y-%m-%d %H:%M:%S.%N')
        end
      end
    end
  end
end
