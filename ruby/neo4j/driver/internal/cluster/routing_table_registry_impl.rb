module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingTableRegistryImpl
        def initialize(connection_pool, rediscovery, clock, logger, routing_table_purge_delay_ms)
          @factory = RoutingTableHandlerFactory.new(connection_pool, rediscovery, clock, logger, routing_table_purge_delay_ms)
          @routing_table_handlers = Concurrent::Hash.new
          @principal_to_database_name_stage = {}
          @clock = clock
          @connection_pool = connection_pool
          @rediscovery = rediscovery
          @log = logger
        end

        def ensure_routing_table(context)
          ensure_database_name_is_completed(context).then_compose do |ctx_and_handler|
            completed_context = ctx_and_handler.context
            handler = ctx_and_handler.handler.nil? ? get_or_create(Util::Futures.join_now_or_else_throw(completed_context.database_name_future, Async::ConnectionContext::PENDING_DATABASE_NAME_EXCEPTION_SUPPLIER)) : ctx_and_handler.handler
            handler.ensure_routing_table(completed_context).then_apply(-> (_ignored) { handler })
          end
        end

        private def ensure_database_name_is_completed(context)
          context_database_name_future = context.database_name_future

          if context_database_name_future.done?
            context_and_handler_stage = java.util.concurrent.CompletableFuture.completed_future(ConnectionContextAndHandler.new(context, nil))
          else
            impersonated_user = context.impersonated_user
            principal = Principal.new(impersonated_user)
            database_name_stage = @principal_to_database_name_stage[principal]
            handler_ref = java.util.concurrent.atomic.AtomicReference.new

            if database_name_stage.nil?
              database_name_future = java.util.concurrent.CompletableFuture.new
              @principal_to_database_name_stage[principal] = database_name_future
              database_name_stage = database_name_future

              routing_table = ClusterRoutingTable.new(DatabaseNameUtil::DEFAULT_DATABASE, @clock)

              @rediscovery.lookup_cluster_composition(routing_table, @connection_pool, context.rediscovery_bookmark, impersonated_user).then_compose do |composition_lookup_result|
                database_name = DatabaseNameUtil.database(composition_lookup_result.cluster_composition.database_name)
                handler = get_or_create(database_name)
                handler_ref.set(handler)
                handler.update_routing_table(composition_lookup_result).then_apply(-> (_ignored) { database_name })
              end.when_complete do |database_name, _throwable|
                    @principal_to_database_name_stage.delete(principal)
                  end.when_complete do |database_name, throwable|
                        if throwable.nil?
                          database_name_future.complete(database_name)
                        else
                          database_name_future.complete_exceptionally(throwable)
                        end
                      end
            end

            context_and_handler_stage =
            database_name_stage.then_apply do |database_name|
              context_database_name_future.complete(database_name)
              ConnectionContextAndHandler.new(context, handler_ref)
            end
          end

          context_and_handler_stage
        end

        def all_servers
          # obviously we just had a snapshot of all servers in all routing tables
          # after we read it, the set could already be changed.
          servers = []

          @routing_table_handlers.values.each do |table_handler|
            servers << table_handler.servers
          end

          servers
        end

        def remove(database_name)
          @routing_table_handlers.delete(database_name)
          @log.debug("Routing table handler for database '#{database_name.description}' is removed.")
        end

        def remove_aged
          @routing_table_handlers.each do |database_name, handler|
            if handler.routing_table_aged?
              @log.info("Routing table handler for database '#{database_name.description}' is removed because it has not been used for a long time. Routing table: #{handler.routing_table}")
              @routing_table_handlers.delete(database_name)
            end
          end
        end

        def get_routing_table_handler(database_name)
          java.util.Optional.of_nullable(@routing_table_handlers[database_name])
        end

        def contains(database_name)
          @routing_table_handlers.keys.include?(database_name)
        end

        def get_or_create(database_name)
          @routing_table_handlers.compute_if_absent(database_name) do |name|
            handler = @factory.new_instance(name, self)
            @log.debug("Routing table handler for database '#{database_name.description}' is added.")
            handler
          end
        end

        private

        class RoutingTableHandlerFactory
          def initialize(connection_pool, rediscovery, clock, logger, routing_table_purge_delay_ms)
            @connection_pool = connection_pool
            @rediscovery = rediscovery
            @clock = clock
            @logger = logger
            @routing_table_purge_delay_ms = routing_table_purge_delay_ms
          end

          def new_instance(database_name, all_tables)
            routing_table = ClusterRoutingTable.new(database_name, @clock)
            RoutingTableHandlerImpl.new(routing_table, @rediscovery, @connection_pool, all_tables, @logger, @routing_table_purge_delay_ms)
          end
        end

        class Principal < Struct.new(:id)
        end

        class ConnectionContextAndHandler
          attr_reader :context, :handler

          def initialize(context, handler)
            @context = context
            @handler = handler
          end
        end
      end
    end
  end
end
