module TestkitBackend
  module Requests
    # Stub; see NewAuthTokenManager.
    class NewBasicAuthTokenManager < Request
      def process
        reference('BasicAuthTokenManager')
      end

      def to_object
        Object.new
      end
    end
  end
end
