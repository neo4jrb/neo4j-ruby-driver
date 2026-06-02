# frozen_string_literal: true

module Neo4j
  module Driver
    # Factory for the "auth token manager" type. Mirrors
    # `org.neo4j.driver.AuthTokenManagers` — but with a Ruby keyword-arg
    # surface matching the JRuby flavour's ext shim
    # (lib/jruby/.../ext/auth_token_managers.rb).
    #
    # The returned object is duck-typed: any value responding to
    #
    #   get_token                                   -> AuthToken
    #   handle_security_exception(token, exception) -> Boolean
    #
    # is a manager. Pass your own instance to `GraphDatabase.driver`
    # instead of an `AuthToken`; no inheritance or interface declaration
    # needed.
    module AuthTokenManagers
      class << self
        # MRI doesn't yet implement Feature:Auth:Managed retry semantics
        # (Java threads them through `ExpirationBasedAuthTokenManager`).
        # Until that path lands, callers can still build a custom
        # manager by hand or via `.custom`.
        def basic(supplier:)
          raise NotImplementedError, 'Feature:Auth:Managed is not yet supported on the MRI driver'
        end

        def bearer(supplier:)
          raise NotImplementedError, 'Feature:Auth:Managed is not yet supported on the MRI driver'
        end

        def custom(get_token:, handle_security_exception:)
          Internal::AuthTokenManagers::Custom.new(get_token, handle_security_exception)
        end
      end
    end
  end
end
