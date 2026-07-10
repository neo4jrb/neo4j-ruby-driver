# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # The driver's clock. Every internal that measures elapsed time — pool
      # idle/lifetime/acquisition, connection deadlines, routing-table ttl,
      # managed-tx retry budget — reads it instead of calling Process/Time
      # directly, and gets it injected (DriverFactory#createClock, threaded
      # through as the `:clock` option). This default reads the real monotonic
      # and wall clocks; testkit-backend supplies its own via the same seam
      # (see Internal::ClockAdapter). The internals are agnostic to which clock
      # they hold — there is no notion of "real" vs "mock" below this line.
      class Clock
        def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        def realtime = ::Time.now
      end
    end
  end
end
