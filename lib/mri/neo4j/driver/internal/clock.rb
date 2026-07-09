# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Time seam for the MRI driver. Every internal that measures elapsed time
      # — pool idle/lifetime/acquisition, connection deadlines, routing-table
      # freshness, managed-tx retry budget — reads the clock through here rather
      # than calling Process.clock_gettime / Time.now directly.
      #
      # In production nothing is installed, so it delegates to the real
      # monotonic and wall clocks (zero behavioural change). testkit-backend
      # installs its mock (a `#now_millis` source) via DriverFactory#createClock
      # → Clock.mock=, so Backend:MockTime tests can freeze time and advance it
      # with FakeTimeTick. This mirrors the Java driver's createClock seam that
      # the jruby flavour already uses.
      module Clock
        class << self
          # A clock responding to #now_millis (epoch milliseconds), or nil to use
          # the real system clocks. Set once per driver by the factory.
          attr_accessor :mock

          # Monotonic seconds — for *durations* (idle-since, lifetime, deadlines),
          # never absolute wall time. Real CLOCK_MONOTONIC when unmocked; derived
          # from the mock's epoch-ms otherwise (callers only ever subtract two
          # readings, so the epoch base is irrelevant).
          def monotonic
            (m = mock) ? m.now_millis / 1000.0 : Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end

          # Wall-clock Time — routing-table freshness (ttl) and the retry budget.
          def realtime
            (m = mock) ? ::Time.at(m.now_millis / 1000.0) : ::Time.now
          end
        end
      end
    end
  end
end
