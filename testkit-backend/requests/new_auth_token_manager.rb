module TestkitBackend
  module Requests
    # Custom AuthTokenManager: testkit-driven token supplier *and*
    # security-exception handler. Both callbacks are relayed to the
    # frontend with the same blocking-read pattern NewBookmarkManager
    # uses for its supplier / consumer.
    class NewAuthTokenManager < Request
      def process
        reference('AuthTokenManager')
      end

      def to_object
        manager = nil
        manager = Neo4j::Driver::AuthTokenManager.new(
          get_token: -> { get_token(manager.object_id) },
          handle_security_exception: ->(token, exc) { handle_security_exception(manager.object_id, token, exc) }
        )
      end

      private

      def get_token(manager_id)
        reply = @command_processor.callback(
          named_entity('AuthTokenManagerGetAuthRequest', id: manager_id, auth_token_manager_id: manager_id))
        Request.object_from(reply.auth)
      end

      def handle_security_exception(manager_id, token, exception)
        @command_processor.callback(
          named_entity('AuthTokenManagerHandleSecurityExceptionRequest',
                       id: manager_id, auth_token_manager_id: manager_id,
                       auth: serialize_auth_token(token), error_code: exception.code)).handled
      end

      # Reverse of AuthorizationToken#to_object — AuthToken back to
      # the testkit named_entity shape. `AuthToken#to_h` is impl-
      # agnostic (MRI returns its Hash directly, JRuby's ext does the
      # conversion).
      def serialize_auth_token(token)
        named_entity('AuthorizationToken', **token.to_h)
      end
    end
  end
end
