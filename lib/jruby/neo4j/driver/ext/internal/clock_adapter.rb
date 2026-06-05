# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # `java.time.Clock` adapter that delegates to any Ruby
        # `clock` object responding to `#now_millis`. Used by
        # `Internal::DriverFactory#to_clock` so testkit-backend's
        # pure-Ruby `TestkitClock` can plug straight into Java's
        # `DriverFactory#createClock` seam.
        class ClockAdapter < java.time.Clock
          def initialize(ruby_clock)
            super()
            @ruby_clock = ruby_clock
          end

          def get_zone
            raise java.lang.UnsupportedOperationException.new
          end

          def with_zone(_zone)
            raise java.lang.UnsupportedOperationException.new
          end

          def instant
            java.time.Instant.of_epoch_milli(@ruby_clock.now_millis)
          end
        end
      end
    end
  end
end
