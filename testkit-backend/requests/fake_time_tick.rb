module TestkitBackend
  module Requests
    # Advance the driver's fake clock by `increment_ms` milliseconds.
    # See FakeTimeInstall.
    class FakeTimeTick < Request
      def process
        Neo4j::Driver::Internal::Clock.tick(increment_ms)
        named_entity('FakeTimeAck')
      end
    end
  end
end
