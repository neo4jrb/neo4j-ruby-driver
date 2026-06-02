

module Neo4j
  module Driver
    # Auth-token manager: anything responding to
    #
    #   get_token                                   -> AuthToken
    #   handle_security_exception(token, exception) -> Boolean
    #
    # is a manager. Pass an instance to `GraphDatabase.driver` in
    # place of an `AuthToken` and the driver will call back into it
    # when it needs a fresh token or when the server rejects the
    # current one.
    #
    # This concrete class is the Proc-based shortcut — supply two
    # callables and you're done. Clients that need richer behaviour
    # subclass and override the methods directly; no inheritance is
    # required, the protocol is duck-typed.
    class AuthTokenManager
      def initialize(get_token, handle_security_exception)
        @get_token = get_token
        @handle_security_exception = handle_security_exception
      end

      def get_token
        @get_token.call
      end

      def handle_security_exception(token, exception)
        @handle_security_exception.call(token, exception)
      end
    end
  end
end
