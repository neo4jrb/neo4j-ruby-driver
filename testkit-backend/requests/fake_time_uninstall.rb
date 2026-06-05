module TestkitBackend
  module Requests
    # Return the driver's clock to system time. See FakeTimeInstall.
    class FakeTimeUninstall < Request
      def process
        Internal::TestkitClock::INSTANCE.uninstall
        Neo4j::Driver::Internal::Clock.reset
        named_entity('FakeTimeAck')
      end
    end
  end
end
