module TestkitBackend
  module Requests
    # Return the testkit clock to system time. See FakeTimeInstall.
    class FakeTimeUninstall < Request
      def process
        Internal::TestkitClock::INSTANCE.uninstall
        named_entity('FakeTimeAck')
      end
    end
  end
end
