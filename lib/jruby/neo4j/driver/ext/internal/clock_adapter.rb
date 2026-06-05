# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # `java.time.Clock` adapter that defers to the impl-agnostic
        # `Neo4j::Driver::Internal::Clock` seam. Installed via
        # `DriverFactory#createClock` so every Java internal consuming
        # a `Clock` (connection pool, retry backoff, liveness checks)
        # sees whatever the seam currently reports.
        class ClockAdapter < java.time.Clock
          def get_zone
            raise java.lang.UnsupportedOperationException.new
          end

          def with_zone(_zone)
            raise java.lang.UnsupportedOperationException.new
          end

          def instant
            java.time.Instant.of_epoch_milli(Neo4j::Driver::Internal::Clock.now_millis)
          end

          # Singleton init lives after the method definitions so JRuby
          # binds the Java proxy against the fully-populated class
          # (otherwise `instant` shows up as unimplemented).
          INSTANCE = new
        end
      end
    end
  end
end
