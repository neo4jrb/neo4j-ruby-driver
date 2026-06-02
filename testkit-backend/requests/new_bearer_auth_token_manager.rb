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
        manager = Neo4j::Driver::AuthTokenManagers.bearer(supplier: -> { supply(manager.object_id) })
      end

      private

      def supply(manager_id)
        @command_processor.process_response(
          named_entity('BearerAuthTokenProviderRequest', id: manager_id, bearer_auth_token_manager_id: manager_id))
        body = @command_processor.process(blocking: true).auth[:data]
        token = Request.object_from(body[:auth])
        expires_in_ms = body[:expiresInMs]
        expiration = expires_in_ms ? java.lang.System.current_time_millis + expires_in_ms : java.lang.Long::MAX_VALUE
        token.expiring_at(expiration)
      end
    end
  end
end
