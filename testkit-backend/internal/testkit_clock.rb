# frozen_string_literal: true

require 'concurrent/atomic/atomic_boolean'
require 'concurrent/atomic/atomic_fixnum'

module TestkitBackend
  module Internal
    # Mockable clock for Backend:MockTime. Pure Ruby, one impl for
    # both driver flavours: testkit-backend installs the singleton
    # into `Neo4j::Driver::Internal::Clock` and the driver's internals
    # (plus our own `ExpirationBasedAuthTokenManager`) consult it via
    # the seam.
    #
    # State lives in concurrent-ruby atomics so the Java driver's
    # pool / retry / liveness threads — which read `now_millis`
    # concurrently with the testkit-backend handler thread calling
    # `install` / `tick` / `uninstall` — never see a stale value.
    # `Concurrent::Atomic{Boolean,Fixnum}` are backed by Java atomics
    # under JRuby and by a Mutex under MRI without a Java reference
    # in sight.
    class TestkitClock
      def initialize
        @fake_mode = Concurrent::AtomicBoolean.new(false)
        @fake_ms = Concurrent::AtomicFixnum.new(0)
      end

      def install
        @fake_ms.value = 0
        @fake_mode.make_true
      end

      def tick(delta_ms)
        @fake_ms.update { |ms| ms + delta_ms }
      end

      def uninstall
        @fake_mode.make_false
      end

      def now_millis
        @fake_mode.true? ? @fake_ms.value : (Time.now.to_f * 1000).to_i
      end

      INSTANCE = new
    end
  end
end
