# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Prepended onto Java's `AuthTokenManagers` singleton so
      # `basic` and `bearer` construct the internal
      # `ExpirationBasedAuthTokenManager` directly — same shape
      # Java's testkit-backend uses — instead of the public Java
      # factory. The internal constructor accepts a `java.time.Clock`,
      # which is how `TestkitClock` plugs into the bearer-token
      # expiration timer.
      module AuthTokenManagers
        AUTHENTICATION =
          java.util.Set.of(Java::OrgNeo4jDriverExceptions::AuthenticationException.java_class)
        AUTHENTICATION_AND_TOKEN_EXPIRED =
          java.util.Set.of(Java::OrgNeo4jDriverExceptions::AuthenticationException.java_class,
                           Java::OrgNeo4jDriverExceptions::TokenExpiredException.java_class)

        def basic(supplier)
          expiration_based_manager(
            -> { supplier.call.expiring_at(java.lang.Long::MAX_VALUE) },
            AUTHENTICATION)
        end

        def bearer(supplier)
          expiration_based_manager(supplier, AUTHENTICATION_AND_TOKEN_EXPIRED)
        end

        private

        def expiration_based_manager(token_supplier, retryable_exception_classes)
          Java::OrgNeo4jDriverInternalSecurity::ExpirationBasedAuthTokenManager.new(
            -> { java.util.concurrent.CompletableFuture.completed_future(token_supplier.call) },
            retryable_exception_classes,
            Internal::TestkitClock::INSTANCE)
        end
      end
    end
  end
end
