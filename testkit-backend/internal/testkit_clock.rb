# frozen_string_literal: true

module TestkitBackend
  module Internal
    # Mockable clock for Backend:MockTime. Pure Ruby, one impl for
    # both driver flavours: testkit-backend installs the singleton
    # into `Neo4j::Driver::Internal::Clock` and the driver's internals
    # (plus our own `ExpirationBasedAuthTokenManager`) consult it via
    # the seam — no Java refs needed here.
    class TestkitClock
      # Backed by Java atomics under JRuby (and a tiny Ruby fallback
      # under MRI). The Java driver's pool / retry / liveness threads
      # read `now_millis` concurrently with the testkit-backend
      # handler thread calling `install` / `tick` / `uninstall`; plain
      # Ruby ivars get no JMM visibility guarantees on JRuby, so a
      # pool thread can otherwise read a stale `@fake_ms` after a
      # tick. Atomics make every read see the latest write.
      if defined?(Java)
        def initialize
          @fake_mode = java.util.concurrent.atomic.AtomicBoolean.new(false)
          @fake_ms = java.util.concurrent.atomic.AtomicLong.new(0)
        end

        def install
          @fake_ms.set(0)
          @fake_mode.set(true)
        end

        def tick(delta_ms)
          @fake_ms.add_and_get(delta_ms)
        end

        def uninstall
          @fake_mode.set(false)
        end

        def now_millis
          @fake_mode.get ? @fake_ms.get : (Time.now.to_f * 1000).to_i
        end
      else
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

      # Singleton init at the bottom so the constructor runs against
      # the fully-populated class (otherwise the ivars never get
      # initialised).
      INSTANCE = new
    end
  end
end
