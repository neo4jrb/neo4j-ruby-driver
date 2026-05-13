module TestkitBackend
  module Requests
    # See AuthTokenManagerGetAuthCompleted.
    class AuthTokenManagerHandleSecurityExceptionCompleted < Request
      def process
        raise NotImplementedError,
              'AuthTokenManager callbacks are not implemented (driver does not advertise Feature:Auth:Managed)'
      end
    end
  end
end
