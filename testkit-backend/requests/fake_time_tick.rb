module TestkitBackend
  module Requests
    # Stub; see FakeTimeInstall.
    class FakeTimeTick < Request
      def process
        named_entity('BackendError',
                     msg: 'FakeTime is not implemented (driver does not advertise Backend:MockTime)')
      end
    end
  end
end
