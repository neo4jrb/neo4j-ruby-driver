# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # MRI counterpart to Java's
      # `org.neo4j.driver.internal.security.StaticAuthTokenManager`.
      # Returns the same `AuthToken` forever and never treats a
      # security exception as retryable. Subclasses our
      # duck-typed `Neo4j::Driver::AuthTokenManager` so the protocol
      # — `get_token` / `handle_security_exception` — matches
      # everything else MRI consumes.
      class StaticAuthTokenManager < AuthTokenManager
        def initialize(token)
          super(
            get_token: -> { token },
            handle_security_exception: ->(_, _) { false }
          )
        end
      end
    end
  end
end
