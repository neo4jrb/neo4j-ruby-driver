module TestkitBackend
  module Requests
    # Freeze the testkit clock at zero — subsequent `FakeTimeTick`
    # requests advance it. The clock is consulted by the driver's
    # pool / retry / liveness internals via the `DriverFactory`'s
    # `createClock` override (testkit's `Internal::DriverFactory`
    # returns the same `TestkitClock` singleton), and by testkit's
    # `ExpirationBasedAuthTokenManager` for bearer-token expiry.
    class FakeTimeInstall < Request
      def process
        Internal::TestkitClock::INSTANCE.install
        named_entity('FakeTimeAck')
      end
    end
  end
end
