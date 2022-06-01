module Neo4j::Driver
  module Internal
    module Cluster
      # This implementation of the {@link RoutingProcedureRunner} access the routing procedure
      # through the bolt's ROUTE message.
      class RouteMessageRoutingProcedureRunner
        attr_writer :routing_table

        def initialize(routing_context)
          @routing_context = routing_context.to_h
        end

        def run(connection, database_name, bookmark, impersonated_user)
          direct_connection = to_direct_connection(connection, database_name, impersonated_user)
          direct_connection.write_and_flush(
            Messaging::Request::RouteMessage.new(@routing_context, bookmark, database_name.database_name,
                                                 impersonated_user),
            Handlers::RouteMessageResponseHandler.new(self))
          RoutingProcedureResponse.new(query(database_name), to_record(routing_table))
        rescue => e
          RoutingProcedureResponse.new(query(database_name), e)
        ensure
          direct_connection.release
        end

        private

        def to_record(routing_table)
          InternalRecord.new(routing_table.keys, routing_table.values)
        end

        def to_direct_connection(connection, database_name, impersonated_user)
          Async::Connection::DirectConnection.new(connection, database_name, AccessMode::READ, impersonated_user)
        end

        def query(database_name)
          Query.new('ROUTE $routing_context $database_name', routing_context: @routing_context,
                    database_name: database_name.database_name)
        end
      end
    end
  end
end
