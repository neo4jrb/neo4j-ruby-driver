# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Freezes the driver's clock. After this, only FakeTimeTick advances
    # virtual time. Used by tests for retry timeout, connection lifetime,
    # bookmark TTL, etc., without real wall-clock waits.
    #
    # DRIVER GAP: the driver reads `Time.now` and friends inline (e.g.
    # in retry logic, connection lifetime checks). Implementing fake-time
    # cleanly requires an injectable clock:
    #   - Introduce Neo4j::Driver::Internal::Clock with .now / .now_ms /
    #     .sleep
    #   - All time-reading code goes through it (one-time refactor)
    #   - FakeTimeInstall swaps in a mockable subclass; FakeTimeTick
    #     advances its internal counter; FakeTimeUninstall restores
    #     the real clock
    # Without this refactor, fake-time tests would silently fail their
    # timing assertions even if they ran. So we stub all three with the
    # same NotImplemented marker.
    class FakeTimeInstall < Data.define
      include Request

      def execute
        Response::DriverError.not_implemented(
          'FakeTimeInstall: injectable Clock not implemented (see handler comment).'
        )
      end
    end
  end
end
