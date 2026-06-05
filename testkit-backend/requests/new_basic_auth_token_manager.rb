module TestkitBackend
  module Requests
    # Basic password-rotation manager — owns the same retry semantics
    # as Java's `AuthTokenManagers.basic` (retry only on
    # `AuthenticationException`, never expires) via the pure-Ruby
    # `ExpirationBasedAuthTokenManager` so testkit drives the same
    # implementation on MRI and JRuby.
    class NewBasicAuthTokenManager < Request
      def process
        reference('BasicAuthTokenManager')
      end

      def to_object
        manager = nil
        manager = Internal::ExpirationBasedAuthTokenManager.new(
          supplier: -> { { auth_token: supply(manager.object_id) } },
          retryable_exceptions: [Neo4j::Driver::Exceptions::AuthenticationException],
          clock: Internal::TestkitClock::INSTANCE
        )
      end

      private

      def supply(manager_id)
        @command_processor.process_response(
          named_entity('BasicAuthTokenProviderRequest', id: manager_id, basic_auth_token_manager_id: manager_id))
        Request.object_from(@command_processor.process(blocking: true).auth)
      end
    end
  end
end
