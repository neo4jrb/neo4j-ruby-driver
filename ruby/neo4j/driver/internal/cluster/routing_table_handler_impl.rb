module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingTableHandlerImpl
        attr_reader :routing_table

        delegate :servers, to: :routing_table

        def initialize(routing_table, rediscovery, connection_pool, routing_table_registry, logging, routing_table_purge_delay_ms)
          @routing_table = routing_table
          @database_name = routing_table.database
          @rediscovery = rediscovery
          @connection_pool = connection_pool
          @routing_table_registry = routing_table_registry
          @log = logging.get_log(self.class)
          @routing_table_purge_delay_ms = routing_table_purge_delay_ms
          @resolved_initial_routers = []
          @refresh_routing_table_future = nil
        end

        def on_connection_failure(address)
          # remove server from the routing table, to prevent concurrent threads from making connections to this address
          routing_table.forget(address)
        end

        def on_write_failure(address)
          routing_table.forget_writer(address)
        end

        def ensure_routing_table(context)
          # refresh is already happening concurrently, just use it's result
          return @refresh_routing_table_future unless @refresh_routing_table_future.nil?

          if routing_table.stale_for?(context.mode)
            # existing routing table is not fresh and should be updated
            @log.debug( "Routing table for database '#{@database_name.description}' is stale. #{routing_table}")

            result_future = java.util.concurrent.CompletableFuture.new
            @refresh_routing_table_future = result_future

            @rediscovery.lookup_cluster_composition(routing_table, @connection_pool, context.rediscovery_bookmark, nil).when_complete do |composition, completion_error|
              error = Util::Futures.completion_exception_cause(completion_error)

              if error.nil?
                fresh_cluster_composition_fetched(composition)
              else
                cluster_composition_lookup_failed(error)
              end
            end

            result_future
          else
            # existing routing table is fresh, use it
            java.util.concurrent.CompletableFuture.completed_future(routing_table)
          end
        end

        def update_routing_table(composition_lookup_result)
          if !@refresh_routing_table_future.nil?
            # refresh is already happening concurrently, just use its result
            @refresh_routing_table_future
          else
            if composition_lookup_result.get_cluster_composition.expiration_timestamp < routing_table.expiration_timestamp
              return java.util.concurrent.CompletableFuture.completed_future(routing_table)
            end

            result_future = java.util.concurrent.CompletableFuture.new
            @refresh_routing_table_future = result_future
            fresh_cluster_composition_fetched(composition_lookup_result)
            result_future
          end
        end

        private def fresh_cluster_composition_fetched(composition_lookup_result)
          begin
            @log.debug("Fetched cluster composition for database '#{@database_name.description}'. #{composition_lookup_result.cluster_composition}")
            routing_table.update(composition_lookup_result.cluster_composition)
            @routing_table_registry.remove_aged

            addresses_to_retain = []
            @routing_table_registry.all_servers.stream.flat_map(BoltServerAddress::unicast_stream).for_each(addresses_to_retain::add)

            composition_lookup_result.resolved_initial_routers.if_present do |addresses|
              @resolved_initial_routers.clear
              @resolved_initial_routers << addresses
            end

            addresses_to_retain << @resolved_initial_routers
            @connection_pool.retain_all(addresses_to_retain)

            @log.debug("Updated routing table for database '#{@database_name.description}'. #{routing_table}")

            routing_table_future = @refresh_routing_table_future
            @refresh_routing_table_future = nil
            routing_table_future.complete( routing_table)
          rescue StandardError => error
            cluster_composition_lookup_failed(error)
          end
        end

        private def cluster_composition_lookup_failed(error)
          @log.error("Failed to update routing table for database '#{database_name.description}'. Current routing table: #{routing_table}.", error)
          @routing_table_registry.remove(database_name)
          routing_table_future = @refresh_routing_table_future
          @refresh_routing_table_future = nil
          routing_table_future.complete_exceptionally(error)
        end

        # This method cannot be synchronized as it will be visited by all routing table handler's threads concurrently
        def routing_table_aged?
          @refresh_routing_table_future.nil? && routing_table.has_been_stale_for?(@routing_table_purge_delay_ms)
        end
      end
    end
  end
end
