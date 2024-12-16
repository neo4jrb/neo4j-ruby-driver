module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingTableHandlerImpl
        attr_reader :routing_table

        delegate :servers, to: :routing_table

        def initialize(routing_table, rediscovery, connection_pool, routing_table_registry, logger, routing_table_purge_delay)
          @routing_table = routing_table
          @database_name = routing_table.database
          @rediscovery = rediscovery
          @connection_pool = connection_pool
          @routing_table_registry = routing_table_registry
          @log = logger
          @routing_table_purge_delay = routing_table_purge_delay
          @mutex = Concurrent::ReentrantReadWriteLock.new
        end

        def on_connection_failure(address)
          # remove server from the routing table, to prevent concurrent threads from making connections to this address
          @routing_table.forget(address)
        end

        def on_write_failure(address)
          @routing_table.forget_writer(address)
        end

        def ensure_routing_table(context)
          @mutex.with_write_lock do
            if @routing_table.stale_for?(context.mode)
              # existing routing table is not fresh and should be updated
              @log.debug("Routing table for database '#{@database_name.description}' is stale. #{@routing_table}")

              fresh_cluster_composition_fetched(
                @rediscovery.lookup_cluster_composition(@routing_table, @connection_pool, context.rediscovery_bookmark,
                                                        nil))
            else
              # existing routing table is fresh, use it
              @routing_table
            end
          rescue => error
            cluster_composition_lookup_failed(error)
          end
        end

        def update_routing_table(composition_lookup_result)
          @mutex.with_write_lock do
            if composition_lookup_result.cluster_composition.expiration_timestamp < @routing_table.expiration_timestamp
              @routing_table
            else
              fresh_cluster_composition_fetched(composition_lookup_result)
            end
          end
        end

        private

        def fresh_cluster_composition_fetched(composition_lookup_result)
          @log.debug("Fetched cluster composition for database '#{@database_name.description}'. #{composition_lookup_result.cluster_composition}")
          @routing_table.update(composition_lookup_result.cluster_composition)
          @routing_table_registry.remove_aged
          addresses_to_retain = @routing_table_registry.all_servers.map(&:unicast_stream).reduce(&:+)

          composition_lookup_result.resolved_initial_routers&.then do |addresses|
            addresses_to_retain.merge(addresses)
          end

          @connection_pool.retain_all(addresses_to_retain)

          @log.debug("Updated routing table for database '#{@database_name.description}'. #{routing_table}")
          @routing_table
        rescue => error
          cluster_composition_lookup_failed(error)
        end

        def cluster_composition_lookup_failed(error)
          @log.error do
            "Failed to update routing table for database '#{@database_name.description}'. Current routing table: #{@routing_table}."
          end
          @log.error(error)
          @routing_table_registry.remove(@database_name)
          raise error
        end

        public

        # This method cannot be synchronized as it will be visited by all routing table handler's threads concurrently
        def routing_table_aged?
          @mutex.with_read_lock { @routing_table.has_been_stale_for?(@routing_table_purge_delay) }
        end
      end
    end
  end
end
