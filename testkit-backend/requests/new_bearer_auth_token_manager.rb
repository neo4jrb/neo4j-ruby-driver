# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Creates a "bearer" (potentially-expiring token) auth-token manager.
    # Same gap as NewAuthTokenManager. Ack with id; no real provider
    # callback yet.
    #
    # DRIVER GAP: see new_auth_token_manager.rb for the full list. The
    # bearer variant additionally tracks expiresInMs from the provider's
    # AuthTokenAndExpiration response and refreshes ahead of time.
    class NewBearerAuthTokenManager < Data.define
      include Request

      def execute
        placeholder = { type: :bearer_auth_token_manager }
        Response::BearerAuthTokenManager.new(id: registry.store(placeholder, prefix: 'authmgr'))
      end
    end
  end
end
