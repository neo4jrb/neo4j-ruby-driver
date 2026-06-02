module TestkitBackend
  module Requests
    # Basic password-rotation manager — Java's AuthTokenManagers.basic
    # wraps a Supplier<AuthToken> that only retries on
    # AuthenticationException. The supplier closure relays to the
    # frontend with the same blocking-read pattern NewAuthTokenManager
    # uses.
    class NewBasicAuthTokenManager < Request
      def process
        reference('BasicAuthTokenManager')
      end

      def to_object
        manager = nil
        manager = Neo4j::Driver::AuthTokenManagers.basic(supplier: -> { supply(manager.object_id) })
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
