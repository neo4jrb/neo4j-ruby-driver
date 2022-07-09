module Neo4j::Driver
  module Internal
    module Cluster

      # This implementation of the {@link RoutingProcedureRunner} works with multi database versions of Neo4j calling
      # the procedure `dbms.routing.getRoutingTable`
      class MultiDatabasesRoutingProcedureRunner < SingleDatabaseRoutingProcedureRunner
        DATABASE_NAME = :database
        MULTI_DB_GET_ROUTING_TABLE = "CALL dbms.routing.getRoutingTable($%s, $%s)" % [SingleDatabaseRoutingProcedureRunner::ROUTING_CONTEXT, DATABASE_NAME]

        private

        def bookmark_holder(bookmark)
          ReadOnlyBookmarkHolder.new(bookmark)
        end

        def procedure_query(server_version, database_name)
          map = {
            SingleDatabaseRoutingProcedureRunner::ROUTING_CONTEXT => @context.to_h,
            DATABASE_NAME => database_name.database_name
          }
          Query.new(MULTI_DB_GET_ROUTING_TABLE, **map)
        end

        def connection(connection)
          Async::Connection::DirectConnection.new(connection, DatabaseNameUtil::SYSTEM_DATABASE, AccessMode::READ, nil)
        end
      end
    end
  end
end
