# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalDriver
        extend AutoClosable
        include ConfigConverter
        include ExceptionCheckable
        include AsyncConverter

        auto_closable :session

        def execute_query(query, auth_token = nil, config = {}, **parameters)
          java_method(:executableQuery, [java.lang.String])
            .call(query)
            .java_method(:withParameters, [java.util.Map])
            .call(parameters.transform_keys(&:to_s))
            .java_method(:withAuthToken, [org.neo4j.driver.AuthToken])
            .call(auth_token)
            .java_method(:withConfig, [org.neo4j.driver.QueryConfig])
            .call(to_java_config(Neo4j::Driver::QueryConfig, **config))
            .java_method(:execute, [])
            .call
        end

        def session(**session_config)
          java_method(:session, [org.neo4j.driver.SessionConfig])
            .call(to_java_config(Neo4j::Driver::SessionConfig, **session_config))
        end

        def async_session(**session_config)
          java_method(:asyncSession, [org.neo4j.driver.SessionConfig])
            .call(to_java_config(Neo4j::Driver::SessionConfig, **session_config))
        end

        def close_async
          to_future(super)
        end

        def verify_connectivity
          check { super }
        end

        def verify_authentication(auth_token)
          check { super }
        end

        def supports_session_auth?
          check { supports_session_auth }
        end
      end
    end
  end
end
