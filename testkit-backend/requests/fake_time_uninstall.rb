module TestkitBackend
  module Requests
    # Return the driver's clock to system time. See FakeTimeInstall.
    class FakeTimeUninstall < Request
      def process
        Neo4j::Driver::Internal::Clock.uninstall
        named_entity('FakeTimeAck')
      end
    end
  end
end
