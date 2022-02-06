module Neo4j::Driver
  module Internal
    module Cluster

      # This implementation of the {@link RoutingProcedureRunner} works with multi database versions of Neo4j calling
      # the procedure `dbms.routing.getRoutingTable`
      class MultiDatabasesRoutingProcedureRunner < SingleDatabaseRoutingProcedureRunner
        DATABASE_NAME = 'database'
        MULTI_DB_GET_ROUTING_TABLE = "CALL dbms.routing.getRoutingTable($%s, $%s)" % [SingleDatabaseRoutingProcedureRunner::ROUTING_CONTEXT, DATABASE_NAME]

        def initialize(context)
          super
        end

        private

        def bookmark_holder(bookmark)
          ReadOnlyBookmarkHolder.new(bookmark)
        end

        def procedure_query(server_version, database_name)
          map = {}
          map[SingleDatabaseRoutingProcedureRunner::ROUTING_CONTEXT] = Values.value(context.to_map)
          map[DATABASE_NAME] = Values.value(database_name.database_name)
          Query.new(MULTI_DB_GET_ROUTING_TABLE, Values.value(map))
        end

        def connection(connection)
          Async::Connection::DirectConnection.new(connection, DatabaseNameUtil::SYSTEM_DATABASE, AccessMode::READ, nil)
        end
      end
    end
  end
end
