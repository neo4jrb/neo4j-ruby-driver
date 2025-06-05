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
          check do
            executable_query(query)
              .with_auth_token(auth_token)
              .with_config(to_java_config(Neo4j::Driver::QueryConfig, **config))
              .with_parameters(to_neo(parameters))
              .execute
          end
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
