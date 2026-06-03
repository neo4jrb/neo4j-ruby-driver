module TestkitBackend
  module Requests
    # Frontend reply to a backend->frontend AuthTokenManagerGetAuthRequest,
    # read inline by NewAuthTokenManager#get_token (it pulls `.auth` off
    # this message). Writes no response of its own —
    # cf. BookmarksSupplierCompleted.
    class AuthTokenManagerGetAuthCompleted < Request
      def process; end
    end
  end
end
