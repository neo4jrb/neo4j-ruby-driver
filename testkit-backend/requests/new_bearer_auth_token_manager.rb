module TestkitBackend
  module Requests
    # Bearer-token manager — same retry semantics as Java's
    # `AuthTokenManagers.bearer` (retries on TokenExpired or
    # Authentication, expiration tracked) via the pure-Ruby
    # `ExpirationBasedAuthTokenManager`. The frontend sends an
    # `expiresInMs` lifetime relative to "now"; we translate to an
    # absolute deadline using the driver's `Internal::Clock` seam so
    # FakeTime-installed tests get the mocked epoch.
    class NewBearerAuthTokenManager < Request
      def process
        reference('BearerAuthTokenManager')
      end

      def to_object
        manager = nil
        manager = Internal::ExpirationBasedAuthTokenManager.new(
          supplier: -> { supply(manager.object_id) },
          retryable_exceptions: [
            Neo4j::Driver::Exceptions::AuthenticationException,
            Neo4j::Driver::Exceptions::TokenExpiredException
          ],
          clock: Internal::TestkitClock::INSTANCE
        )
      end

      private

      def supply(manager_id)
        body = @command_processor.callback(
          named_entity('BearerAuthTokenProviderRequest', id: manager_id, bearer_auth_token_manager_id: manager_id)).auth[:data]
        token = Request.object_from(body[:auth])
        expires_in_ms = body[:expiresInMs]
        expires_at_ms = expires_in_ms && Internal::TestkitClock::INSTANCE.now_millis + expires_in_ms
        { auth_token: token, expires_at_ms: expires_at_ms }
      end
    end
  end
end
