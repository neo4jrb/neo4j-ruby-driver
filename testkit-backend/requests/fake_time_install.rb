module TestkitBackend
  module Requests
    # Freeze the driver's internal clock at zero — subsequent
    # `FakeTimeTick` requests advance it. Used by Backend:MockTime
    # tests to deterministically exercise time-sensitive paths
    # (bearer-token expiry, connection idle / max-lifetime, retry
    # backoff). The driver consults `Internal::Clock` for "now"; we
    # plug our `TestkitClock` in for the duration of the test.
    class FakeTimeInstall < Request
      def process
        Internal::TestkitClock::INSTANCE.install
        Neo4j::Driver::Internal::Clock.use(Internal::TestkitClock::INSTANCE)
        named_entity('FakeTimeAck')
      end
    end
  end
end
