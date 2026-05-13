module TestkitBackend
  module Requests
    # See AuthTokenManagerGetAuthCompleted.
    class BearerAuthTokenProviderCompleted < Request
      def process
        raise NotImplementedError,
              'BearerAuthTokenProvider callbacks are not implemented (driver does not advertise Feature:Auth:Managed)'
      end
    end
  end
end
