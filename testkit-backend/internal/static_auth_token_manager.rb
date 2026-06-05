# frozen_string_literal: true

module TestkitBackend
  module Internal
    # Mirror of Java's `org.neo4j.driver.internal.security.StaticAuthTokenManager`.
    # Returns the same `AuthToken` forever and never treats a
    # security exception as retryable. testkit wraps the
    # `AuthorizationToken` it gets from the wire in one of these so
    # `Internal::DriverFactory#new_instance` only ever has to handle
    # an `AuthTokenManager` — same shape Java's testkit-backend uses.
    class StaticAuthTokenManager < Neo4j::Driver::AuthTokenManager
      def initialize(token)
        super(
          get_token: -> { token },
          handle_security_exception: ->(_, _) { false }
        )
      end
    end
  end
end
