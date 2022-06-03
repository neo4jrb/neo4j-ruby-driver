module Neo4j::Driver
  module Internal
    module Cluster

      # This implementation of the {@link RoutingProcedureRunner} works with single database versions of Neo4j calling
      # the procedure `dbms.cluster.routing.getRoutingTable`
      class SingleDatabaseRoutingProcedureRunner
        ROUTING_CONTEXT = 'context'
        GET_ROUTING_TABLE = "CALL dbms.cluster.routing.getRoutingTable($#{ROUTING_CONTEXT})"

        def initialize(context)
          @context = context
        end

        def run(connection, database_name, bookmark, impersonated_user)
          delegate = connection(connection)
          procedure = procedure_query(connection.server_version, database_name)
          bookmark_holder = bookmark_holder(bookmark)
          run_procedure(delegate, procedure, bookmark_holder).then_compose do |records|
            release_connection(delegate, records).handle do |records, error|
              process_procedure_response(procedure, records, error)
            end
          end
        end

        private

        def connection(connection)
          Async::Connection::DirectConnection.new(connection, default_database, AccessMode::WRITE, nil)
        end

        def procedure_query(server_version, database_name)
          if database_name.database_name.present?
            raise Exceptions::FatalDiscoveryException, "Refreshing routing table for multi-databases is not supported in server version lower than 4.0. Current server version: #{server_version}. Database name: '#{database_name.description}'"
          end

          Query.new(GET_ROUTING_TABLE, Values.parameters(ROUTING_CONTEXT, @context.to_map))
        end

        def bookmark_holder(_ignored)
          BookmarkHolder::NO_OP
        end

        def run_procedure(connection, procedure, bookmark_holder)
          connection.protocol
                    .run_in_auto_commit_transaction(connection, procedure, bookmark_holder, TransactionConfig.empty,
                                                    Handlers::Pulln::FetchSizeUtil::UNLIMITED_FETCH_SIZE)
                    .async_result.then_compose(Async::ResultCursor::list_async)
        end

        def release_connection(connection, records)
          # It is not strictly required to release connection after routing procedure invocation because it'll
          # be released by the PULL_ALL response handler after result is fully fetched. Such release will happen
          # in background. However, releasing it early as part of whole chain makes it easier to reason about
          # rediscovery in stub server tests. Some of them assume connections to instances not present in new
          # routing table will be closed immediately.
          connection.release.then_apply(->(_ignore) { records } )
        end

        def process_procedure_response(procedure, records, error)
          cause = Util::Futures.completion_exception_cause(error)

          return RoutingProcedureResponse.new(procedure, records) if cause.nil?

          handle_error(procedure, cause)
        end

        def handle_error(procedure, error)
          return RoutingProcedureResponse.new(procedure, records) if error.is_a? Exceptions::ClientException

          raise java.util.concurrent.CompletionException, error
        end
      end
    end
  end
end
