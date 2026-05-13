module TestkitBackend
  module Requests
    # Stub: the Ruby driver doesn't advertise Backend:MockTime, so
    # testkit shouldn't drive these — but register for parity.
    class FakeTimeInstall < Request
      def process
        raise NotImplementedError,
              'FakeTime is not implemented (driver does not advertise Backend:MockTime)'
      end
    end
  end
end
