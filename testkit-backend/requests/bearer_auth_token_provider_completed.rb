module TestkitBackend
  module Requests
    # Frontend reply to a backend->frontend BearerAuthTokenProviderRequest,
    # read inline by NewBearerAuthTokenManager#supply. Writes no response.
    class BearerAuthTokenProviderCompleted < Request
      def process; end
    end
  end
end
