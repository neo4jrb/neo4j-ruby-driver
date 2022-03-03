module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingProcedureClusterCompositionProvider
        PROTOCOL_ERROR_MESSAGE = "Failed to parse '%s' result received from server due to "

        def initialize(clock, routing_context)
          @clock = clock
          @single_database_routing_procedure_runner = SingleDatabaseRoutingProcedureRunner.new(routing_context)
          @multi_database_routing_procedure_runner = MultiDatabasesRoutingProcedureRunner.new(routing_context)
          @route_message_routing_procedure_runner = RouteMessageRoutingProcedureRunner.new(routing_context)
        end

        def get_cluster_composition(connection, database_name, bookmark, impersonated_user)
          runner = if Messaging::Request::MultiDatabaseUtil.supports_route_message(connection)
                    @route_message_routing_procedure_runner
                  elsif Messaging::Request::MultiDatabaseUtil.supports_multi_database(connection)
                    @multi_database_routing_procedure_runner
                  else
                    @single_database_routing_procedure_runner
                  end

          runner.run(connection, database_name, bookmark, impersonated_user).then_apply do
            self::process_routing_response
          end
        end

        def process_routing_response(response)
          if !response.success?
            raise java.util.concurrent.CompletionException, "Failed to run '#{invoked_procedure_string(response)}' on server. Please make sure that there is a Neo4j server or cluster up running.", response.error
          end

          records = response.records
          now = clock.millis

          # the record size is wrong
          if records.size != 1
            raise Exceptions::ProtocolException, "#{PROTOCOL_ERROR_MESSAGE % invoked_procedure_string(response)} records received '#{records.size}' is too few or too many."
          end

          # failed to parse the record
          begin
            cluster = ClusterComposition.parse( records[0], now)
          rescue Exceptions::Value::ValueException => e
            raise Exceptions::ProtocolException, "#{PROTOCOL_ERROR_MESSAGE % invoked_procedure_string(response)} unparsable record received. #{e}"
          end

          # the cluster result is not a legal reply
          if !cluster.has_routers_and_readers?
            raise Exceptions::ProtocolException, "#{PROTOCOL_ERROR_MESSAGE % invoked_procedure_string(response)} no router or reader found in response."
          end

          # all good
          cluster
        end

        def invoked_procedure_string(response)
          query = response.procedure
          query.text + '' + query.parameters
        end
      end
    end
  end
end
