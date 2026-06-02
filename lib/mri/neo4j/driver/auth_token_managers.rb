# frozen_string_literal: true

module Neo4j
  module Driver
    # Mirrors `org.neo4j.driver.AuthTokenManagers`. Each factory wraps a
    # supplier callable into an `AuthTokenManager`. The supplier shape
    # matches Java's:
    #
    #   basic(supplier)  — supplier returns an `AuthToken`.
    #   bearer(supplier) — supplier returns an `AuthToken` together with
    #                       an expiration timestamp.
    #
    # MRI does not yet implement Feature:Auth:Managed retry semantics
    # (Java's `ExpirationBasedAuthTokenManager` retries `basic` on
    # `AuthenticationException`, `bearer` on that plus
    # `TokenExpiredException`). Until that lands, the manager works as
    # a refresh source — `get_token` consults the supplier on every
    # call — but `handle_security_exception` always returns false.
    module AuthTokenManagers
      class << self
        def basic(supplier)
          AuthTokenManager.new(get_token: supplier, handle_security_exception: ->(_, _) { false })
        end

        def bearer(supplier)
          AuthTokenManager.new(get_token: supplier, handle_security_exception: ->(_, _) { false })
        end
      end
    end
  end
end
