# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Mirrors Java's `AuthTokenManagers.basic(Supplier<AuthToken>)` /
      # `bearer(Supplier<AuthTokenAndExpiration>)` factories with Ruby
      # keyword-arg surfaces. The `custom` factory returns the shared
      # duck-typed `Internal::AuthTokenManagers::Custom` (same class
      # MRI uses); the boundary into Java's `AuthTokenManager`
      # interface is crossed by `Internal::AuthTokenManagerAdapter`
      # inside `GraphDatabase.driver`, so client code never names a
      # Java type.
      module AuthTokenManagers
        def basic(supplier:)
          super(supplier)
        end

        def bearer(supplier:)
          super(supplier)
        end

        def custom(get_token:, handle_security_exception:)
          Neo4j::Driver::Internal::AuthTokenManagers::Custom.new(get_token, handle_security_exception)
        end
      end
    end
  end
end
