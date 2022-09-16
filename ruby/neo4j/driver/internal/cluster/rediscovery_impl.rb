module Neo4j::Driver
  module Internal
    module Cluster
      class RediscoveryImpl
        NO_ROUTERS_AVAILABLE = "Could not perform discovery for database '%s'. No routing server available."
        RECOVERABLE_ROUTING_ERROR = "Failed to update routing table with server '%s'."
        RECOVERABLE_DISCOVERY_ERROR_WITH_SERVER = "Received a recoverable discovery error with server '%s', will continue discovery with other routing servers if available. Complete failure is reported separately from this entry."
        INVALID_BOOKMARK_CODE = 'Neo.ClientError.Transaction.InvalidBookmark'
        INVALID_BOOKMARK_MIXTURE_CODE = 'Neo.ClientError.Transaction.InvalidBookmarkMixture'

        def initialize(initial_router, settings, provider, event_executor_group, resolver, logger, domain_name_resolver)
          @initial_router = initial_router
          @settings = settings
          @log = logger
          @provider = provider
          @resolver = resolver
          @event_executor_group = event_executor_group
          @domain_name_resolver = Internal::Validator.require_non_nil!(domain_name_resolver)
        end

        # Given a database and its current routing table, and the global connection pool, use the global cluster composition provider to fetch a new cluster
        # composition, which would be used to update the routing table of the given database and global connection pool.

        # @param routingTable   current routing table of the given database.
        # @param connectionPool connection pool.
        # @return new cluster composition and an optional set of resolved initial router addresses.
        def lookup_cluster_composition(
          routing_table, connection_pool, bookmark, impersonated_user,
          failures = 0,
          previous_delay = 0,
          base_error = Exceptions::ServiceUnavailableException.new(NO_ROUTERS_AVAILABLE % routing_table.database.description))

          lookup(routing_table, connection_pool, bookmark, impersonated_user, base_error) ||
            if failures > @settings.max_routing_failures
              # now we throw our saved error out
              raise base_error
            else
              next_delay = [@settings.retry_timeout_delay, previous_delay * 2].max
              @log.info("Unable to fetch new routing table, will try again in #{next_delay} ms")
              sleep next_delay
              lookup_cluster_composition(routing_table, connection_pool, bookmark, impersonated_user, failures + 1, next_delay, base_error)
            end
        end

        def resolve
          exception = nil

          resolved_addresses = @resolver.call(@initial_router).flat_map do |server_address|
            resolve_all_by_domain_name(server_address).unicast_stream
            # rescue java.net.UnknownHostException => e
          rescue SocketError => e
            exception ||= e
          end

          # give up only if there are no addresses to work with at all
          raise exception if resolved_addresses.empty? && exception

          resolved_addresses
        end

        private

        def lookup(routing_table, connection_pool, bookmark, impersonated_user, base_error)
          if routing_table.prefer_initial_router
            lookup_on_initial_router_then_on_known_routers(routing_table, connection_pool, bookmark, impersonated_user, base_error)
          else
            lookup_on_known_routers_then_on_initial_router(routing_table, connection_pool, bookmark, impersonated_user, base_error)
          end
        end

        def lookup_on_known_routers_then_on_initial_router(routing_table, connection_pool, bookmark, impersonated_user, base_error)
          seen_servers = Set.new
          lookup_on_known_routers(routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error) ||
            lookup_on_initial_router(routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
        end

        def lookup_on_initial_router_then_on_known_routers(routing_table, connection_pool, bookmark, impersonated_user, base_error)
          lookup_on_initial_router(routing_table, connection_pool, Set.new, bookmark, impersonated_user, base_error) ||
            lookup_on_known_routers(routing_table, connection_pool, Set.new, bookmark, impersonated_user, base_error)
        end

        def lookup_on_known_routers(routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
          routing_table.routers.lazy.map do |address|
            lookup_on_router(address, true, routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
          end.first&.then(&ClusterCompositionLookupResult.method(:new))
        end

        def lookup_on_initial_router(routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
          resolved_routers = resolve
          (resolved_routers - seen_servers.to_a).lazy.filter_map do |address|
            lookup_on_router(address, false, routing_table, connection_pool, nil, bookmark,
                             impersonated_user, base_error)
          end.first&.then { |composition| ClusterCompositionLookupResult.new(composition, Set.new(resolved_routers)) }
        end

        def lookup_on_router(router_address, resolve_address, routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
          address = resolve_address ? resolve_by_domain_name_or_throw_completion_exception(router_address, routing_table) : router_address
          seen_servers&.send(:<<, address)
          connection = connection_pool.acquire(address)
          ImpersonationUtil.ensure_impersonation_support(connection, impersonated_user)
          @provider.get_cluster_composition(connection, routing_table.database, bookmark, impersonated_user)
        rescue => error
          handle_routing_procedure_error(error, routing_table, router_address, base_error)
        end

        def handle_routing_procedure_error(error, routing_table, router_address, base_error)
          raise error if must_abort_discovery(error)

          # Retriable error happened during discovery.
          discovery_error = Exceptions::DiscoveryException.new(nil, RECOVERABLE_ROUTING_ERROR % router_address, error)
          Util::Futures.combine_errors(base_error, discovery_error) # we record each failure here
          warning_message = RECOVERABLE_DISCOVERY_ERROR_WITH_SERVER % router_address
          @log.warn(warning_message)
          @log.debug(discovery_error)
          routing_table.forget(router_address)
          nil
        end

        def must_abort_discovery(error)
          !error.is_a?(Exceptions::AuthorizationExpiredException) && error.is_a?(Exceptions::SecurityException) ||
            error.is_a?(Exceptions::FatalDiscoveryException) ||
            error.is_a?(Exceptions::IllegalStateException) &&
              Spi::ConnectionPool::CONNECTION_POOL_CLOSED_ERROR_MESSAGE == error.message ||
            error.is_a?(Exceptions::ClientException) &&
              [INVALID_BOOKMARK_CODE, INVALID_BOOKMARK_MIXTURE_CODE].include?(error.code) ||
          # Not sure why this is not im java
            !error.is_a?(Exceptions::Neo4jException) ||
            Util::ErrorUtil.fatal?(error)
        end

        def resolve_by_domain_name_or_throw_completion_exception(address, routing_table)
          resolved_address = resolve_all_by_domain_name(address)
          routing_table.replace_router_if_present(address, resolved_address)

          resolved_address.unicast_stream.first or
            raise Exceptions::IllegalStateException,
                  'Unexpected condition, the ResolvedBoltServerAddress must always have at least one unicast address'
        end

        def resolve_all_by_domain_name(address)
          ResolvedBoltServerAddress.new(address.host, address.port, *@domain_name_resolver.call(address.host))
        end
      end
    end
  end
end
