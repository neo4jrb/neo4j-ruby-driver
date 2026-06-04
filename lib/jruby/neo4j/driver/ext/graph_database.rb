# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module GraphDatabase
        extend AutoCloseable
        include ConfigConverter
        include ExceptionCheckable

        auto_closeable :driver

        def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, auth_token_manager: nil, **config)
          internal_driver(uri, auth_token, auth_token_manager: auth_token_manager, **config)
        end

        # Always routes through our `Internal::DriverFactory` subclass
        # — that's the seam that wires `TestkitClock` into the pool /
        # retry / liveness paths (`createClock` override). Production
        # behaviour is unchanged because `TestkitClock` only diverges
        # from system time after `Internal::Clock.install` is called.
        def internal_driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, auth_token_manager: nil, **config, &domain_name_resolver)
          check do
            java_uri = java.net.URI.create(uri.to_s)
            java_config = to_java_config(Neo4j::Driver::Config, **config)
            # Mirrors Java's GraphDatabase.driver — a nil AuthToken
            # arg is treated as AuthTokens.none rather than crashing
            # StaticAuthTokenManager's null guard.
            manager = auth_token_manager ||
                      org.neo4j.driver.internal.security.StaticAuthTokenManager.new(
                        auth_token || Neo4j::Driver::AuthTokens.none)
            Internal::DriverFactory
              .new(&domain_name_resolver)
              .new_instance(java_uri, manager,
                            nil, # ClientCertificateManager — added in newer Java DriverFactory
                            java_config)
          end
        end
      end
    end
  end
end
