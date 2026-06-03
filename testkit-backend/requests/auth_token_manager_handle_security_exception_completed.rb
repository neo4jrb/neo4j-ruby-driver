module TestkitBackend
  module Requests
    # Frontend reply to a backend->frontend
    # AuthTokenManagerHandleSecurityExceptionRequest, read inline by
    # NewAuthTokenManager#handle_security_exception (it pulls `.handled`
    # off this message). Writes no response of its own.
    class AuthTokenManagerHandleSecurityExceptionCompleted < Request
      def process; end
    end
  end
end
