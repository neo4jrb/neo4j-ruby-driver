module TestkitBackend
  module Requests
    # Stub; see FakeTimeInstall.
    class FakeTimeTick < Request
      def process
        raise NotImplementedError,
              'FakeTime is not implemented (driver does not advertise Backend:MockTime)'
      end
    end
  end
end
