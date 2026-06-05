# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module GraphDatabase
        extend AutoCloseable
        include ConfigConverter
        include ExceptionCheckable

        auto_closeable :driver

        def driver(uri, auth_token = nil, auth_token_manager: nil, **config)
          check do
            java_config = to_java_config(Neo4j::Driver::Config, **config)
            auth_class = auth_token_manager ? org.neo4j.driver.AuthTokenManager : org.neo4j.driver.AuthToken
            auth = auth_token_manager || auth_token || Driver::AuthTokens.none
            java_method(:driver, [java.lang.String, auth_class, org.neo4j.driver.Config])
              .call(uri.to_s, auth, java_config)
          end
        end
      end
    end
  end
end
