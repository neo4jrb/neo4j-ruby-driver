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
      end
    end
  end
end
