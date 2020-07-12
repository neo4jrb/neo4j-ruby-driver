# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module GraphDatabase
        extend AutoClosable
        include ConfigConverter
        include ExceptionCheckable

        auto_closable :driver, :routing_driver

        def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, **config)
          check do
            java_method(:driver, [java.lang.String, org.neo4j.driver.AuthToken, org.neo4j.driver.Config])
              .call(uri.to_s, auth_token, to_java_config(Neo4j::Driver::Config, config))
          end
        end

        def routing_driver(routing_uris, auth_token, **config)
          check do
            super(routing_uris.map { |uri| java.net.URI.create(uri.to_s) }, auth_token,
                  to_java_config(Neo4j::Driver::Config, config))
          end
        end
      end
    end
  end
end
