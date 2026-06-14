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

        # Routing table for `database` (testkit GetRoutingTable). Returns
        # Java's RoutingTable (routers/writers/readers + expirationTimestamp);
        # the path to it is the driver's business, not testkit's.
        def routing_table(database)
          routing_table_registry.routing_table_handler(database).routing_table
        end

        # Force a routing-table refresh (testkit ForcedRoutingTableUpdate).
        # Drive the registry's ensureRoutingTable — a fresh/aged table is
        # stale, so this triggers a real ROUTE and populates the handler.
        # ImmutableObservation is an empty marker interface, so a bare impl
        # is enough.
        def routing_table_refresh(database, bookmarks)
          db_name = Neo4j::Driver::Internal::DatabaseName.database(database)
          params = Java::OrgNeo4jDriverInternalShadedBoltConnection::RoutedBoltConnectionParameters
                   .builder
                   .with_database_name(db_name)
                   .with_bookmarks(java.util.HashSet.new(Array(bookmarks)))
                   .build
          routing_table_registry
            .ensure_routing_table(java.util.concurrent.CompletableFuture.completed_future(db_name),
                                  params, NOOP_OBSERVATION)
            .to_completable_future.get
        end

        NOOP_OBSERVATION = Class.new do
          include Java::OrgNeo4jDriverInternalShadedBoltConnectionObservation::ImmutableObservation
        end.new

        private

        # Reflect from the session factory down to the RoutedBoltConnectionSource
        # that owns the routing-table registry. The number of delegating
        # wrappers varies by driver version (6.1.x adds a
        # ProviderClosingBoltConnectionSource), so unwrap `delegate` until the
        # source with a `registry` field.
        def routing_table_registry
          source = Internal::Reflection.field(session_factory, 'connectionSource')
          until Internal::Reflection.field?(source, 'registry')
            unless Internal::Reflection.field?(source, 'delegate')
              raise KeyError, "No routing-table registry in the connection-source chain (#{source.java_class.simple_name})"
            end

            source = Internal::Reflection.field(source, 'delegate')
          end
          Internal::Reflection.field(source, 'registry')
        end
      end
    end
  end
end
