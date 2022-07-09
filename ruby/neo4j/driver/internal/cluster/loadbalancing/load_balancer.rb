module Neo4j::Driver
  module Internal
    module Cluster
      module Loadbalancing
        class LoadBalancer
          CONNECTION_ACQUISITION_COMPLETION_FAILURE_MESSAGE = 'Connection acquisition failed for all available addresses.'
          CONNECTION_ACQUISITION_COMPLETION_EXCEPTION_MESSAGE = "Failed to obtain connection towards %s server. Known routing table is: %s"
          CONNECTION_ACQUISITION_ATTEMPT_FAILURE_MESSAGE = "Failed to obtain a connection towards address %s, will try other addresses if available. Complete failure is reported separately from this entry."
          BOLT_SERVER_ADDRESSES_EMPTY_ARRAY = []

          delegate :close, to: :@connection_pool

          def initialize(initial_router, settings, connection_pool, event_executor_group, logger, load_balancing_strategy, resolver, &domain_name_resolver)
            clock = Util::Clock::System
            @connection_pool = connection_pool
            @rediscovery = create_rediscovery(event_executor_group, initial_router, resolver, settings, clock, logger, domain_name_resolver)
            @routing_tables = create_routing_tables(connection_pool, @rediscovery, settings, clock, logger)
            @load_balancing_strategy = load_balancing_strategy
            @event_executor_group = event_executor_group
            @log = logger
          end

          def acquire_connection(context)
            handler = @routing_tables.ensure_routing_table(context)
            connection = acquire(context.mode, handler.routing_table)
            Async::Connection::RoutingConnection.new(connection, context.database_name, context.mode,
                                                     context.impersonated_user, handler)
          end

          def verify_connectivity
            @routing_tables.ensure_routing_table(Async::ImmutableConnectionContext.simple(supports_multi_db?))
          rescue Exceptions::ServiceUnavailableException
            raise Exceptions::ServiceUnavailableException,
                  'Unable to connect to database management service, ensure the database is running and that there is a working network connection to it.'
          end

          def routing_table_registry
            @routing_tables
          end

          def supports_multi_db?
            addresses = @rediscovery.resolve
            base_error = Exceptions::ServiceUnavailableException.new("Failed to perform multi-databases feature detection with the following servers: #{addresses}")
            addresses.lazy.map do |address|
              private_suports_multi_db?(address)
            rescue Exceptions::SecurityException
              raise
            rescue => error
              Util::Futures.combine_errors(base_error, error)
            end.find { |result| !result.nil? } or raise base_error
          end

          private

          def private_suports_multi_db?(address)
            conn = @connection_pool.acquire(address)
            Messaging::Request::MultiDatabaseUtil.supports_multi_database?(conn)
          ensure
            conn&.release
          end

          def acquire(mode, routing_table, attempt_errors = [])
            addresses = addresses_by_mode(mode, routing_table)
            address = select_address(mode, addresses)

            unless address
              error = Exceptions::SessionExpiredException.new(CONNECTION_ACQUISITION_COMPLETION_EXCEPTION_MESSAGE % [mode, routing_table])
              attempt_errors.each(&error.method(:add_suppressed))
              @log.error(CONNECTION_ACQUISITION_COMPLETION_FAILURE_MESSAGE)
              @log.error(error)
              raise error
            end

            begin
              @connection_pool.acquire(address)
            rescue Exceptions::ServiceUnavailableException => error
              @log.warn { CONNECTION_ACQUISITION_ATTEMPT_FAILURE_MESSAGE % address }
              @log.debug(error)
              attempt_errors << error
              routing_table.forget(address)
              acquire(mode, routing_table, attempt_errors)
            end
          end

          def addresses_by_mode(mode, routing_table)
            case mode
            when AccessMode::READ
              routing_table.readers
            when AccessMode::WRITE
              routing_table.writers
            else
              raise unknown_mode mode
            end
          end

          def select_address(mode, addresses)
            case mode
            when AccessMode::READ
              @load_balancing_strategy.select_reader(addresses)
            when AccessMode::WRITE
              @load_balancing_strategy.select_writer(addresses)
            else
              raise unknown_mode mode
            end
          end

          def create_routing_tables(connection_pool, rediscovery, settings, clock, logger)
            RoutingTableRegistryImpl.new(connection_pool, rediscovery, clock, logger, DurationNormalizer.milliseconds(settings.routing_table_purge_delay))
          end

          def create_rediscovery(event_executor_group, initial_router, resolver, settings, clock, logger, domain_name_resolver)
            cluster_composition_provider = RoutingProcedureClusterCompositionProvider.new(clock, settings.routing_context)
            RediscoveryImpl.new(initial_router, settings, cluster_composition_provider, event_executor_group, resolver, logger, domain_name_resolver)
          end

          def unknown_mode(mode)
            ArgumentError.new("Mode '#{mode}' is not supported")
          end
        end
      end
    end
  end
end
