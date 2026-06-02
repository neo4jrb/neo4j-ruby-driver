module TestkitBackend
  module Requests
    # Frontend reply to a backend->frontend BasicAuthTokenProviderRequest,
    # read inline by NewBasicAuthTokenManager#supply. Writes no response.
    class BasicAuthTokenProviderCompleted < Request
      def process; end
    end
  end
end
