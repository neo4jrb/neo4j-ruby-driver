module TestkitBackend
  module Requests
    # Stub; see NewAuthTokenManager.
    class NewBearerAuthTokenManager < Request
      def process
        reference('BearerAuthTokenManager')
      end

      def to_object
        Object.new
      end
    end
  end
end
