# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalDriver
        extend AutoCloseable
        include ConfigConverter
        include ExceptionCheckable
        include AsyncConverter

        auto_closeable :session

        # See lib/mri/.../driver.rb. auth_token is part of `config` in the
        # published surface, but Java's builder takes it as a separate
        # setter — pull it out before handing the rest to QueryConfig.
        def execute_query(query, parameters = {}, config = {})
          auth_token = config.delete(:auth_token)
          check do
            executable_query(query)
              .with_auth_token(auth_token)
              .with_config(to_java_config(Neo4j::Driver::QueryConfig, **config))
              .with_parameters(to_neo(parameters))
              .execute
          end
        end

        def session(auth_token: nil, **session_config)
          # auth_token is a per-session override (Feature:API:Session:AuthConfig);
          # Java exposes it via Driver.session(Class<T>, SessionConfig, AuthToken).
          # Passing null defers to the driver default — same as the
          # 2-arg overload, so we can always take the long path.
          java_method(:session,
                      [java.lang.Class, org.neo4j.driver.SessionConfig, org.neo4j.driver.AuthToken])
            .call(org.neo4j.driver.Session.java_class,
                  to_java_config(Neo4j::Driver::SessionConfig, **session_config),
                  auth_token)
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
