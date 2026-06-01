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

        def verify_authentication(auth_token = nil)
          check { super(auth_token) }
        end

        def supports_session_auth?
          check { supports_session_auth }
        end

        # Mirrors MRI's Driver#server_info — returns a Summary::ServerInfo
        # struct populated from the negotiated connection (no extra
        # wire traffic). Java doesn't expose `serverInfo()` on the
        # Driver interface (it's on ResultSummary), so we synthesise it
        # by running a trivial query and lifting the ServerInfo from
        # its summary. One round-trip; happens at most when callers
        # ask.
        def server_info
          session do |s|
            s.run('RETURN 1').consume.server
          end
        end
      end
    end
  end
end
