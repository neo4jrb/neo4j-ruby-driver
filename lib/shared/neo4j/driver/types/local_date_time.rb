# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Bolt LocalDateTime — a wall-clock datetime with no timezone
      # (java.time.LocalDateTime). Stored as the wire-format pair
      # (epoch_seconds, nanoseconds), where epoch_seconds encodes the
      # wall-clock components as if they were UTC — so the value reads the
      # same regardless of the host TZ.
      #
      # There is deliberately no #to_time: a zone-less value cannot become a
      # zoned Ruby Time without inventing a zone, and every serious datetime
      # library refuses that implicit conversion (Java's LocalDateTime forces
      # .atZone/.atOffset; Python yields a naive datetime). Read the fields via
      # the component getters instead.
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

        # Capture the Time's displayed wall clock, encoded as if UTC. The
        # Time's own zone is irrelevant — only the clock face it shows, so
        # from_time(t) and from_time(t.utc) generally differ (as they should).
        def self.from_time(time)
          new(::Time.utc(time.year, time.month, time.day,
                         time.hour, time.min, time.sec).to_i, time.nsec)
        end

        def self.parse(string)
          # Strip a trailing timezone if present — a naive datetime ignores it.
          naive = string.sub(/[Z+\-]\d{2}:?\d{2}?$/, '')
          time = PARSE_FORMATS.lazy.filter_map { |fmt| ::Time.strptime(naive, fmt) rescue nil }.first
          raise ArgumentError, "Invalid LocalDateTime format: #{string}" unless time
          from_time(time)
        end

        def year       = wall_clock.year
        def month      = wall_clock.month
        def day        = wall_clock.day
        def hour       = wall_clock.hour
        def minute     = wall_clock.min
        def second     = wall_clock.sec
        def nanosecond = @nanoseconds

        # Add a numeric or ActiveSupport::Duration. A wall clock has no DST,
        # so this is plain second arithmetic; sub-second precision preserved.
        def +(seconds)
          total = (@epoch_seconds * NANOS_PER_SECOND) + @nanoseconds +
                  (seconds.to_f * NANOS_PER_SECOND).round
          self.class.new(total / NANOS_PER_SECOND, total % NANOS_PER_SECOND)
        end

        def to_s
          wall_clock.strftime('%Y-%m-%d %H:%M:%S.%N')
        end

        private

        # epoch_seconds read back as its wall clock. UTC by construction, so
        # the components never depend on the host TZ.
        def wall_clock
          ::Time.at(@epoch_seconds, @nanoseconds.to_i, :nanosecond, in: 'UTC')
        end
      end
    end
  end
end
