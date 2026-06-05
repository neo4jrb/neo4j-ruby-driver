module TestkitBackend
  module Requests
    # Advance the driver's fake clock by `increment_ms` milliseconds.
    # See FakeTimeInstall.
    class FakeTimeTick < Request
      def process
        Internal::TestkitClock::INSTANCE.tick(increment_ms)
        named_entity('FakeTimeAck')
      end
    end
  end
end
