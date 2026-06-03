module TestkitBackend
  module Requests
    # Bearer-token manager — Java's AuthTokenManagers.bearer wraps a
    # Supplier<AuthTokenAndExpiration> that retries on TokenExpired or
    # Authentication exceptions. The supplier closure relays to the
    # frontend; the completed reply carries both a fresh
    # AuthorizationToken and an `expiresInMs` lifetime (nil means
    # never-expiring → Long::MAX_VALUE).
    class NewBearerAuthTokenManager < Request
      def process
        reference('BearerAuthTokenManager')
      end

      def to_object
        manager = nil
        manager = Neo4j::Driver::AuthTokenManagers.bearer(-> { supply(manager.object_id) })
      end

      private

      # `expires_in_ms` is relative to "now" on the wire; nil means
      # "no expiration", which we encode as the max long timestamp the
      # driver's bearer factory recognises as "never refresh".
      NEVER_EXPIRES = (1 << 63) - 1

      def supply(manager_id)
        @command_processor.process_response(
          named_entity('BearerAuthTokenProviderRequest', id: manager_id, bearer_auth_token_manager_id: manager_id))
        body = @command_processor.process(blocking: true).auth[:data]
        token = Request.object_from(body[:auth])
        expires_in_ms = body[:expiresInMs]
        expiration = expires_in_ms ? Time.now.to_i * 1000 + expires_in_ms : NEVER_EXPIRES
        token.expiring_at(expiration)
      end
    end
  end
end
