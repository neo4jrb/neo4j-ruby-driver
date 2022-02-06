module Neo4j::Driver
  module Internal
    module Cluster

      # This implementation of the {@link RoutingProcedureRunner} access the routing procedure
      # through the bolt's ROUTE message.
      class RouteMessageRoutingProcedureRunner
        def initialize(routing_context, create_completable_future = java.util.concurrent.CompletableFuture::new)
          @routing_context = routing_context.to_map.entry_set.stream.collect(java.util.stream.Collectors.to_map(java.util.Map.Entry::get_key, -> (entry) { Values.value(entry.get_value) } ))
          @create_completable_future = create_completable_future
        end

        def run(connection, database_name, bookmark, impersonated_user)
          completable_future = @create_completable_future

          direct_connection = to_direct_connection(connection, database_name, impersonated_user)
          direct_connection.write_and_flush(Messaging::Request::RouteMessage.new(@routing_context, bookmark, database_name.database_name.or_else(nil), impersonated_user),
                                            Handlers::RouteMessageResponseHandler.new(completable_future))

          completable_future.then_apply do |routing_table|
            RoutingProcedureResponse.new(query(database_name), java.util.Collections.singleton_list(to_record(routing_table)))
          end.exceptionally do |throwable|
                RoutingProcedureResponse.new(query(database_name), throwable.cause)
              end.then_compose do |routing_procedure_response|
                    direct_connection.release.then_apply(-> { routing_procedure_response } )
                  end
        end

        private

        def to_record(routing_table)
          InternalRecord.new(routing_table.keys, routing_table.values)
        end

        def to_direct_connection(connection, database_name, impersonated_user)
          Async::Connection::DirectConnection.new(connection, database_name, AccessMode::READ, impersonated_user)
        end

        def query(database_name)
          params = {}
          params['routing_context'] = @routing_context
          params['database_name'] = database_name.database_name
          Query.new('ROUTE $routingContext $databaseName', params)
        end
      end
    end
  end
end
