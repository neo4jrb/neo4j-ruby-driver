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

        # Store the Time's wall clock (its date and time-of-day *in its own
        # zone*), dropping the zone. We read that wall clock off the instant
        # using the offset the Time already carries — we never invent a zone,
        # so from_time(t) and from_time(t.utc) differ (they show different
        # clocks). epoch_seconds encodes it as-if-UTC per the class contract.
        def self.from_time(time)
          new(time.to_i + time.utc_offset, time.nsec)
        end

        def self.parse(string)
          # Strip trailing timezone if present — naive datetime ignores it.
          naive = string.sub(/[Z+-]\d{2}:?\d{2}?$/, '')
          time = PARSE_FORMATS.lazy.filter_map do |fmt|
            ::Time.strptime(naive, fmt)
          rescue StandardError
            nil
          end.first
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
        def +(other)
          total = (@epoch_seconds * NANOS_PER_SECOND) + @nanoseconds +
                  (other.to_f * NANOS_PER_SECOND).round
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
