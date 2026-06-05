# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module GraphDatabase
        extend AutoCloseable
        include ConfigConverter
        include ExceptionCheckable

        auto_closeable :driver

        # Production path: goes through Java's static
        # `GraphDatabase.driver` and so picks up the default
        # `DriverFactory` + `Clock.SYSTEM`. testkit-backend uses
        # `internal_driver` instead when it needs FakeTime / a custom
        # resolver — that's the seam that swaps in `TestkitClock`.
        def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, auth_token_manager: nil, **config)
          check do
            java_config = to_java_config(Neo4j::Driver::Config, **config)
            auth_class = auth_token_manager ? org.neo4j.driver.AuthTokenManager : org.neo4j.driver.AuthToken
            auth = auth_token_manager || auth_token
            java_method(:driver, [java.lang.String, auth_class, org.neo4j.driver.Config])
              .call(uri.to_s, auth, java_config)
          end
        end

        def internal_driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, auth_token_manager: nil, **config, &domain_name_resolver)
          check do
            java_uri = java.net.URI.create(uri.to_s)
            java_config = to_java_config(Neo4j::Driver::Config, **config)
            manager = auth_token_manager ||
                      org.neo4j.driver.internal.security.StaticAuthTokenManager.new(auth_token)
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
