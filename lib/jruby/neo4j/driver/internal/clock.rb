# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Test seam — testkit-backend (and only testkit-backend) drives
      # this; production code never installs a fake clock. Hands off
      # to the JRuby ext's `TestkitClock` singleton which is wired
      # into the Java driver's internal clock seams (DriverFactory's
      # `createClock`, ExpirationBasedAuthTokenManager's clock arg).
      #
      # MRI ships a parallel `Internal::Clock` that raises until the
      # MRI side of Backend:MockTime is implemented; the seam is the
      # same shape so testkit-backend code doesn't fork on impl.
      module Clock
        module_function

        def install
          Ext::Internal::TestkitClock::INSTANCE.install
        end

        def tick(delta_ms)
          Ext::Internal::TestkitClock::INSTANCE.tick(delta_ms)
        end

        def uninstall
          Ext::Internal::TestkitClock::INSTANCE.uninstall
        end

        # Current epoch milliseconds — system clock when no fake is
        # installed; fake otherwise. testkit-backend uses this so the
        # `expires_in_ms` math in bearer-token supply respects the
        # mocked clock.
        def millis
          Ext::Internal::TestkitClock::INSTANCE.millis
        end
      end
    end
  end
end
