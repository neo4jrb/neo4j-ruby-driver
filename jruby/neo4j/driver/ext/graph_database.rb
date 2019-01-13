# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module GraphDatabase
        def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, config = {})
          java_method(:driver, [java.lang.String, org.neo4j.driver.v1.AuthToken, org.neo4j.driver.v1.Config])
            .call(uri, auth_token, to_java_config(config))
        rescue Java::OrgNeo4jDriverV1Exceptions::Neo4jException => e
          e.reraise
        end

        private

        def to_java_config(hash)
          hash.reduce(Neo4j::Driver::Config.build) { |object, key_value| object.send(*config_method(*key_value)) }
              .to_config
        end

        def config_method(key, value)
          return :without_encryption if key == :encryption && !value

          [:"with_#{key}", value, (java.util.concurrent.TimeUnit::SECONDS if key.to_s.match?(/Time(out)?$/i))].compact
        end
      end
    end
  end
end
