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
          check do
            java_config = to_java_config(Neo4j::Driver::Config, **config)
            if auth_token_manager
              java_method(:driver, [java.lang.String, org.neo4j.driver.AuthTokenManager, org.neo4j.driver.Config])
                .call(uri.to_s, to_java_auth_manager(auth_token_manager), java_config)
            else
              java_method(:driver, [java.lang.String, org.neo4j.driver.AuthToken, org.neo4j.driver.Config])
                .call(uri.to_s, auth_token, java_config)
            end
          end
        end

        def internal_driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, auth_token_manager: nil, **config, &domain_name_resolver)
          check do
            java_uri = java.net.URI.create(uri.to_s)
            java_config = to_java_config(Neo4j::Driver::Config, **config)
            manager = auth_token_manager ? to_java_auth_manager(auth_token_manager) :
                      org.neo4j.driver.internal.security.StaticAuthTokenManager.new(auth_token)
            Internal::DriverFactory
              .new(&domain_name_resolver)
              .new_instance(java_uri, manager,
                            nil, # ClientCertificateManager — added in newer Java DriverFactory
                            java_config)
          end
        end

        private

        # `auth_token_manager` may be a Java AuthTokenManager
        # (`AuthTokenManagers.basic / .bearer` return one of these
        # directly — Java's `ExpirationBasedAuthTokenManager`) — pass
        # through. Or a duck-typed Ruby manager
        # (`Neo4j::Driver::AuthTokenManager` or any client class
        # responding to `get_token`) — wrap in the JRuby-only adapter
        # that bridges to Java's interface.
        def to_java_auth_manager(manager)
          manager.is_a?(Java::OrgNeo4jDriver::AuthTokenManager) ? manager :
            Internal::AuthTokenManagerAdapter.new(manager)
        end
      end
    end
  end
end
