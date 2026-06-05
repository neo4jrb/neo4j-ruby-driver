# frozen_string_literal: true

module TestkitBackend
  module Internal
    # Mockable clock for Backend:MockTime. Pure Ruby, one impl for
    # both driver flavours: testkit-backend installs the singleton
    # into `Neo4j::Driver::Internal::Clock` and the driver's internals
    # (plus our own `ExpirationBasedAuthTokenManager`) consult it via
    # the seam — no Java refs needed here.
    class TestkitClock
      INSTANCE = new

      def initialize
        @fake_mode = false
        @fake_ms = 0
      end

      def install
        @fake_mode = true
        @fake_ms = 0
      end

      def tick(delta_ms)
        @fake_ms += delta_ms
      end

      def uninstall
        @fake_mode = false
      end

      def now_millis
        @fake_mode ? @fake_ms : (Time.now.to_f * 1000).to_i
      end
    end
  end
end
