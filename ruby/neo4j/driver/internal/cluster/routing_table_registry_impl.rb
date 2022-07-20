module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingTableRegistryImpl
        def initialize(connection_pool, rediscovery, clock, logger, routing_table_purge_delay)
          @factory = RoutingTableHandlerFactory.new(connection_pool, rediscovery, clock, logger, routing_table_purge_delay)
          @routing_table_handlers = Concurrent::Map.new
          @principal_to_database_name = {}
          @clock = clock
          @connection_pool = connection_pool
          @rediscovery = rediscovery
          @log = logger
          @mutex = Mutex.new
        end

        def ensure_routing_table(context)
          ctx_and_handler = ensure_database_name_is_completed(context)
          (ctx_and_handler.handler || get_or_create(context.database_name))
            .tap { |handler| handler.ensure_routing_table(ctx_and_handler.context) }
        end

        private def ensure_database_name_is_completed(context)
          context_database_name = context.database_name

          return ConnectionContextAndHandler.new(context, nil) if context_database_name
          @mutex.synchronize do
            return ConnectionContextAndHandler.new(context, nil) if context_database_name

            impersonated_user = context.impersonated_user
            principal = Principal.new(impersonated_user)
            database_name = @principal_to_database_name[principal]
            handler_ref = Concurrent::AtomicReference.new

            if database_name.nil?
              @principal_to_database_name[principal] = database_name

              routing_table = ClusterRoutingTable.new(DatabaseNameUtil::DEFAULT_DATABASE, @clock)

              composition_lookup_result = @rediscovery.lookup_cluster_composition(routing_table, @connection_pool, context.rediscovery_bookmark, impersonated_user)
              database_name = DatabaseNameUtil.database(composition_lookup_result.cluster_composition.database_name)
              handler = get_or_create(database_name)
              handler_ref.set(handler)
              handler.update_routing_table(composition_lookup_result)
              @principal_to_database_name.delete(principal)
            end

            context.database_name = database_name
            ConnectionContextAndHandler.new(context, handler_ref.get)
          end
        end

        def all_servers
          # obviously we just had a snapshot of all servers in all routing tables
          # after we read it, the set could already be changed.
          @routing_table_handlers.values.map(&:servers).reduce(&:+)
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

        def routing_table_handler(database_name)
          @routing_table_handlers[database_name]
        end

        # For tests
        delegate :key?, to: :@routing_table_handlers

        def get_or_create(database_name)
          @routing_table_handlers.compute_if_absent(database_name) do
            # TODO: Verify if applies
            # Note: Atomic methods taking a block do not allow the self instance to be used within the block. Doing so will cause a deadlock.
            handler = @factory.new_instance(database_name, self)
            @log.debug("Routing table handler for database '#{database_name.description}' is added.")
            handler
          end
        end

        private

        class RoutingTableHandlerFactory
          def initialize(connection_pool, rediscovery, clock, logger, routing_table_purge_delay)
            @connection_pool = connection_pool
            @rediscovery = rediscovery
            @clock = clock
            @logger = logger
            @routing_table_purge_delay = routing_table_purge_delay
          end

          def new_instance(database_name, all_tables)
            routing_table = ClusterRoutingTable.new(database_name, @clock)
            RoutingTableHandlerImpl.new(routing_table, @rediscovery, @connection_pool, all_tables, @logger, @routing_table_purge_delay)
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
