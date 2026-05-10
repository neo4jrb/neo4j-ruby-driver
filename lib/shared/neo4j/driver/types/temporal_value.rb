# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Shared base for the Bolt temporal value types: Duration,
      # LocalDateTime, LocalTime, OffsetTime. Each subclass declares its
      # `significant_fields` and gets `<=>`, `==`, `eql?`, `hash` derived
      # from them automatically. Comparable mixed in here gives `<`, `>`,
      # `between?`, `clamp` etc. for free.
      class TemporalValue
        include Comparable

        NANOS_PER_SECOND = 1_000_000_000
        NANOS_PER_MINUTE = 60 * NANOS_PER_SECOND
        NANOS_PER_HOUR   = 60 * NANOS_PER_MINUTE
        NANOS_PER_DAY    = 24 * NANOS_PER_HOUR

        def self.significant_fields
          raise NotImplementedError, "#{self} must define .significant_fields"
        end

        def significant
          self.class.significant_fields.map { send(it) }
        end

        def <=>(other)
          return nil unless other.is_a?(self.class)
          significant <=> other.significant
        end

        def ==(other)
          other.is_a?(self.class) && significant == other.significant
        end
        alias eql? ==

        def hash
          significant.hash
        end
      end
    end
  end
end
