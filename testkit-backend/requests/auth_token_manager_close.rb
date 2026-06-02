module TestkitBackend
  module Requests
    # Frees the cached manager (custom / basic / bearer — testkit shares
    # the id space across all three) and echoes back the id wrapped in an
    # AuthTokenManager named_entity.
    class AuthTokenManagerClose < Request
      def process
        delete(id)
        named_entity('AuthTokenManager', id: id)
      end
    end
  end
end
