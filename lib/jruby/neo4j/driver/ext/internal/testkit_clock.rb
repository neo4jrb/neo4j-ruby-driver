# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # JRuby-only mockable `java.time.Clock`. Acts as the system
        # clock unless `Neo4j::Driver::Internal::Clock.install` has
        # been called (only ever from testkit-backend). Wired into
        # the driver at two seams:
        #   - `Ext::Internal::DriverFactory#create_clock` (pool /
        #     retry / liveness use this).
        #   - `Ext::AuthTokenManagers.basic / .bearer` (bearer-token
        #     expiry uses this).
        # Mirrors the singleton-with-fake-mode shape in the Java
        # testkit-backend's TestkitClock.
        class TestkitClock < java.time.Clock
          def initialize
            super
            @fake_mode = false
            @fake_time_ms = 0
          end

          def install
            @fake_mode = true
            @fake_time_ms = 0
          end

          def tick(delta_ms)
            @fake_time_ms += delta_ms
          end

          def uninstall
            @fake_mode = false
          end

          def fake?
            @fake_mode
          end

          def get_zone
            raise java.lang.UnsupportedOperationException.new
          end

          def with_zone(_zone)
            raise java.lang.UnsupportedOperationException.new
          end

          def instant
            java.time.Instant.of_epoch_milli(@fake_mode ? @fake_time_ms : java.lang.System.current_time_millis)
          end

          # Singleton init lives after the method definitions so JRuby
          # binds the Java method table (abstract `instant` in
          # particular) against the fully-populated class.
          INSTANCE = new
        end
      end
    end
  end
end
