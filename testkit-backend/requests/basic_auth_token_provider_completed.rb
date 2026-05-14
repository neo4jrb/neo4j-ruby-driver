module TestkitBackend
  module Requests
    # See AuthTokenManagerGetAuthCompleted.
    class BasicAuthTokenProviderCompleted < Request
      def process
        named_entity('BackendError',
                     msg: 'BasicAuthTokenProvider callbacks are not implemented (driver does not advertise Feature:Auth:Managed)')
      end
    end
  end
end
