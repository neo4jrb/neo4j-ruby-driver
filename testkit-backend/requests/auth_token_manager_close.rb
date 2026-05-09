# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Closes any auth-token manager (the id space is shared between
    # NewAuthTokenManager / NewBasicAuthTokenManager / NewBearerAuthTokenManager
    # — testkit explicitly says so). Idempotent close-style: lenient
    # delete, no error if already gone.
    class AuthTokenManagerClose < Data.define(:id)
      include Request

      def execute
        registry.delete(id)
        Response::AuthTokenManager.new(id: id)
      end
    end
  end
end
