module TestkitBackend
  module Requests
    # Stub; see NewAuthTokenManager.
    class AuthTokenManagerClose < Request
      def process
        delete(id)
        named_entity('AuthTokenManager', id: id)
      end
    end
  end
end
