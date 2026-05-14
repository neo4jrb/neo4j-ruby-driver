module TestkitBackend
  module Requests
    # See AuthTokenManagerGetAuthCompleted.
    class AuthTokenManagerHandleSecurityExceptionCompleted < Request
      def process
        named_entity('BackendError',
                     msg: 'AuthTokenManager callbacks are not implemented (driver does not advertise Feature:Auth:Managed)')
      end
    end
  end
end
