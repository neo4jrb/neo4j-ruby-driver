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
          @domain_name_resolver = java.util.Objects.require_non_null(domain_name_resolver)
        end

        # Given a database and its current routing table, and the global connection pool, use the global cluster composition provider to fetch a new cluster
        # composition, which would be used to update the routing table of the given database and global connection pool.

        # @param routingTable   current routing table of the given database.
        # @param connectionPool connection pool.
        # @return new cluster composition and an optional set of resolved initial router addresses.
        def lookup_cluster_composition(routing_table, connection_pool, bookmark, impersonated_user, failures = nil, previous_delay = nil, result = nil, base_error = nil)
          result = java.util.concurrent.CompletableFuture.new

          # if we failed discovery, we will chain all errors into this one.
          base_error = Exceptions::ServiceUnavailableException.new(NO_ROUTERS_AVAILABLE % routing_table.database.description)

          lookup(routing_table, connection_pool, bookmark, impersonated_user, base_error).when_complete do |composition_lookup_result, completion_error|
            error = Util::Futures.completion_exception_cause(completion_error)

            if !error.nil?
              result.complete_exceptionally(error)
            elsif !composition_lookup_result.nil?
              result.complete(composition_lookup_result)
            else
              new_failures = failures + 1

              if new_failures >= @settings.max_routing_failures
                # now we throw our saved error out
                result.complete_exceptionally(base_error)
              else
                next_delay = java.lang.Math.max(@settings.retry_timeout_delay, previous_delay * 2)
                @log.info("Unable to fetch new routing table, will try again in #{next_delay} ms")

                @event_executor_group.next.schedule(next_delay, java.util.concurrent.TimeUnit::MILLISECONDS) do
                  lookup_cluster_composition(routing_table, connection_pool, bookmark, impersonated_user, new_failures, next_delay, result, base_error)
                end
              end
            end
          end

          result
        end

        def resolve
          resolved_addresses = java.util.LinkedList.new
          exception = nil

          @resolver.resolve(initial_router).each do |server_address|
            begin
              resolve_all_by_domain_name(server_address).unicast_stream.for_each(resolved_addresses::add)
            rescue java.net.UnknownHostException => e
              if exception.nil?
                exception = e
              else
                exception.add_suppressed(e)
              end
            end
          end

          # give up only if there are no addresses to work with at all
          if resolved_addresses.empty? && !exception.nil?
            raise exception
          end

          resolved_addresses
        end

        private

        def lookup(routing_table, connection_pool, bookmark, impersonated_user, base_error)
          composition_stage =  if routing_table.prefer_initial_router
                                lookup_on_initial_router_then_on_known_routers(routing_table, connection_pool, bookmark, impersonated_user, base_error)
                              else
                                lookup_on_known_routers_then_on_initial_router(routing_table, connection_pool, bookmark, impersonated_user, base_error)
                              end
        end

        def lookup_on_known_routers_then_on_initial_router(routing_table, connection_pool, bookmark, impersonated_user, base_error)
          seen_servers = {}

          lookup_on_known_routers(routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error).then_compose do |composition_lookup_result|
            if composition_lookup_result.nil?
              java.util.concurrent.CompletableFuture.completed_future(composition_lookup_result)
            end

            lookup_on_initial_router(routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
          end
        end

        def lookup_on_initial_router_then_on_known_routers(routing_table, connection_pool, bookmark, impersonated_user, base_error)
          seen_servers = [].freeze

          lookup_on_initial_router(routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error).then_compose do |composition_lookup_result|
            if composition_lookup_result.nil?
              java.util.concurrent.CompletableFuture.completed_future(composition_lookup_result)
            end

            lookup_on_known_routers(routing_table, connection_pool, {}, bookmark, impersonated_user, base_error)
          end
        end

        def lookup_on_known_routers(routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
          result = Util::Futures.completed_with_null

          routing_table.routers.each do |address|
            result = result.then_compose do |composition|
                       if !composition.nil?
                         java.util.concurrent.CompletableFuture.completed_future(composition)
                       else
                         lookup_on_router(address, true, routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
                       end
                     end
          end

          result.then_apply do |composition|
            composition.nil? ? nil : ClusterCompositionLookupResult.new(composition)
          end
        end

        def lookup_on_initial_router(routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
          begin
            resolved_routers = resolve
          rescue StandardError => error
            Util::Futures.failed_future(error)
          end

          resolved_router_set = [resolved_routers]
          resolved_routers - seen_servers

          result = Util::Futures.completed_with_null

          resolved_routers.each do |address|
            result = result.then_compose do |composition|
                       if !composition.nil?
                         java.util.concurrent.CompletableFuture.completed_future(composition)
                       else
                         lookup_on_router(address, false, routing_table, connection_pool, nil, bookmark, impersonated_user, base_error)
                       end
                     end
          end

          result.then_apply do |composition|
            composition.nil? ? nil : ClusterCompositionLookupResult.new(composition, resolved_router_set)
          end
        end

        def lookup_on_router(router_address, resolve_address, routing_table, connection_pool, seen_servers, bookmark, impersonated_user, base_error)
          address_future = java.util.concurrent.CompletableFuture.completed_future(router_address)

          address_future.then_apply do |address|
            resolve_address ? resolve_by_domain_name_or_throw_completion_exception(address, routing_table) : address
          end.then_apply do |address|
                add_and_return(seen_servers, address)
              end.then_compose do
                    connection_pool::acquire
                  end.then_apply do |connection|
                        ImpersonationUtil.ensure_impersonation_support(connection, impersonated_user)
                      end.then_compose do |connection|
                            @provider.get_cluster_composition(connection, routing_table.database, bookmark, impersonated_user)
                          end.handle do |response, error|
                                cause = Util::Futures.completion_exception_cause(error)

                                if !cause.nil?
                                  handle_routing_procedure_error(cause, routing_table, router_address, base_error)
                                else
                                  response
                                end
                              end
        end

        def handle_routing_procedure_error(error, routing_table, router_address, base_error)
          raise java.util.concurrent.CompletionException, error if must_abort_discovery(error)

          # Retriable error happened during discovery.
          discovery_error = Exceptions::DiscoveryException.new(RECOVERABLE_ROUTING_ERROR % router_address, error)
          Util::Futures.combine_errors(base_error, discovery_error) # we record each failure here
          warning_message = RECOVERABLE_DISCOVERY_ERROR_WITH_SERVER % router_address
          @log.warn(warning_message)
          @log.debug(warning_message, discovery_error)
          routing_table.forget(router_address)
          nil
        end

        def must_abort_discovery(throwable)
          abort = if !(throwable.is_a? Exceptions::AuthorizationExpiredException) && (throwable.is_a? Exceptions::SecurityException)
                    true
                  elsif throwable.is_a? Exceptions::FatalDiscoveryException
                    true
                  elsif throwable.is_a? Exceptions::IllegalStateException && Spi::ConnectionPool::CONNECTION_POOL_CLOSED_ERROR_MESSAGE == throwable.message
                    true
                  elsif throwable.is_a? Exceptions::ClientException
                    code = throwable.code
                    INVALID_BOOKMARK_CODE.eql?(code) || INVALID_BOOKMARK_MIXTURE_CODE.eql?(code)
                  end
        end

        def add_and_return(collection, element)
          collection << element unless collection.nil?

          element
        end

        def resolve_by_domain_name_or_throw_completion_exception(address, routing_table)
          begin
            resolved_address = resolve_all_by_domain_name(address)
            routing_table.replace_router_if_present(address, resolved_address)

            resolved_address.unicast_stream.find_first.or_else_throw do
              Exceptions::IllegalStateException.new('Unexpected condition, the ResolvedBoltServerAddress must always have at least one unicast address')
            end
          rescue StandardError => e
            raise java.util.concurrent.CompletionException, e
          end
        end

        def resolve_all_by_domain_name(address)
          ResolvedBoltServerAddress.new(address.host, address.port, domain_name_resolver.resolve(address.host))
        end
      end
    end
  end
end
