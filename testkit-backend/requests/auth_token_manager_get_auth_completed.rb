module TestkitBackend
  module Requests
    # Frontend response to a backend->frontend
    # AuthTokenManagerGetAuthRequest. The Ruby driver never emits that
    # request (no managed-auth path), so testkit shouldn't send the
    # completion. Stub for parity with the Java backend.
    class AuthTokenManagerGetAuthCompleted < Request
      def process
        named_entity('BackendError',
                     msg: 'AuthTokenManager callbacks are not implemented (driver does not advertise Feature:Auth:Managed)')
      end
    end
  end
end
