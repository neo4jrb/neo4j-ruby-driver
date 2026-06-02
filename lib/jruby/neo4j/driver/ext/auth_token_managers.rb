# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Mirrors Java's `AuthTokenManagers.basic(Supplier<AuthToken>)` /
      # `bearer(Supplier<AuthTokenAndExpiration>)` factories with Ruby
      # keyword-arg surfaces. For the full-callback case (`get_token` +
      # `handle_security_exception`) clients use
      # `Neo4j::Driver::AuthTokenManager.new(...)` directly — that's
      # the shared duck-typed entry point, and the boundary into Java's
      # `AuthTokenManager` interface is crossed by
      # `Internal::AuthTokenManagerAdapter` inside `GraphDatabase.driver`.
      module AuthTokenManagers
        def basic(supplier:)
          super(supplier)
        end

        def bearer(supplier:)
          super(supplier)
        end
      end
    end
  end
end
