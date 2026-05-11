# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module GraphDatabase
        extend AutoCloseable
        include ConfigConverter
        include ExceptionCheckable

        auto_closeable :driver

        def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, **config)
          check do
            java_method(:driver, [java.lang.String, org.neo4j.driver.AuthToken, org.neo4j.driver.Config])
              .call(uri.to_s, auth_token, to_java_config(Neo4j::Driver::Config, **config))
          end
        end

        def internal_driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, **config, &domain_name_resolver)
          check do
            java_uri = java.net.URI.create(uri.to_s)
            java_config = to_java_config(Neo4j::Driver::Config, **config)
            Internal::DriverFactory
              .new(&domain_name_resolver)
              .new_instance(java_uri,
                            org.neo4j.driver.internal.security.StaticAuthTokenManager.new(auth_token),
                            nil, # ClientCertificateManager — added in newer Java DriverFactory
                            java_config)
          end
        end
      end
    end
  end
end
