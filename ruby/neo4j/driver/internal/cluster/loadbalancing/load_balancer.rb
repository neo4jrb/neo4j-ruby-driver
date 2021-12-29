module Neo4j::Driver
  module Internal
    module Cluster
      module Loadbalancing
        class LoadBalancer
          CONNECTION_ACQUISITION_COMPLETION_FAILURE_MESSAGE = 'Connection acquisition failed for all available addresses.'
          CONNECTION_ACQUISITION_COMPLETION_EXCEPTION_MESSAGE = "Failed to obtain connection towards %s server. Known routing table is: %s"
          CONNECTION_ACQUISITION_ATTEMPT_FAILURE_MESSAGE = "Failed to obtain a connection towards address %s, will try other addresses if available. Complete failure is reported separately from this entry."
          BOLT_SERVER_ADDRESSES_EMPTY_ARRAY = []

          attr_reader :routing_tables

          delegate :close, to: :@connection_pool

          def initialize(connection_pool, routing_tables, rediscovery, load_balancing_strategy, event_executor_group, logging)
            @connection_pool = connection_pool
            @routing_tables = routing_tables
            @rediscovery = rediscovery
            @load_balancing_strategy = load_balancing_strategy
            @event_executor_group = event_executor_group
            @log = logging.get_log(self.class)
          end

          def acquire_connection(context)
            routing_tables.ensure_routing_table(context).then_compose do |handler|
              acquire(context.mode, handler.routing_table).then_apply do |connection|
                Async::Connection::RoutingConnection.new(connection,
                                                         Util::Futures.join_now_or_else_throw(context.database_name_future, Async::ConnectionContext::PENDING_DATABASE_NAME_EXCEPTION_SUPPLIER),
                                                         context.mode, context.impersonated_user, handler)
              end
            end
          end

          def verify_connectivity
            self.supports_multi_db.then_compose do |supports|
              routing_tables.ensure_routing_table(Async::ImmutableConnectionContext.simple(supports)) do |_, error|
                if !error.nil?
                  cause = Util::Futures.completion_exception_cause(error)

                  if cause.instance_of? Exceptions::ServiceUnavailableException
                    raise Util::Futures.as_completion_exception(Neo4j::Driver::Exceptions::ServiceUnavailableException.new('Unable to connect to database management service, ensure the database is running and that there is a working network connection to it.', cause))
                  end

                  raise Util::Futures.as_completion_exception(cause)
                end
              end
            end
          end

          def supports_multi_db
            begin
              addresses = @rediscovery.resolve
            rescue StandardError => error
              return Util::Futures.failed_future(error)
            end

            result = Util::Futures.completed_with_null
            base_error = Exceptions::ServiceUnavailableException.new("Failed to perform multi-databases feature detection with the following servers: #{addresses}")

            addresses.each do |address|
              result = Util::Futures.on_error_continue(result, base_error) do |completion_error|
                # We fail fast on security errors
                error = Util::Futures.completion_exception_cause(completion_error)

                Util::Futures.failed_future(error) if error.instance_of? Exceptions::SecurityException

                @connection_pool.acquire(address).then_compose do |conn|
                  supports_multi_database = Messaging::Request::MultiDatabaseUtil.supports_multi_database(conn)
                  conn.release.then_apply(-> (_ignored) { supports_multi_database })
                end
              end
            end

            Util::Futures.on_error_continue(result, base_error) do |completion_error|
              # If we failed with security errors, then we rethrow the security error out, otherwise we throw the chained errors.
              error = Util::Futures.completion_exception_cause(completion_error)

              Util::Futures.failed_future(error) if error.instance_of? Exceptions::SecurityException

              Util::Futures.failed_future(base_error)
            end
          end

          private

          def acquire(mode, routing_table, result = nil, attempt_errors = nil)
            unless result.present? && attempt_errors.present?
              result = java.util.concurrent.CompletableFuture.new
              attempt_exceptions = []
            end

            addresses = addresses_by_mode(mode, routing_table)
            address = select_address(mode, addresses)

            if address.nil?
              completion_error = Exceptions::SessionExpiredException.new(CONNECTION_ACQUISITION_COMPLETION_EXCEPTION_MESSAGE % [mode, routing_table])
              attempt_errors.each { completion_error::add_suppressed }

              @log.error(CONNECTION_ACQUISITION_COMPLETION_FAILURE_MESSAGE % completion_error)
              result.complete_exceptionally(completion_error)
              return
            end

            @connection_pool.acquire(address).when_complete do |connection, completion_error|
              error = Util::Futures.completion_exception_cause(completion_error)

              if error.nil?
                result.complete(connection)
              else
                if !error.instance_of? Exceptions::ServiceUnavailableException
                  result.complete_exceptionally(error)
                else
                  attempt_message = CONNECTION_ACQUISITION_ATTEMPT_FAILURE_MESSAGE % address
                  @log.warn(attempt_message)
                  @log.debug(attempt_message, error)
                  attempt_errors << error
                  routing_table.forget(address)
                  @event_executor_group.next.execute(-> () { acquire(mode, routing_table, result, attempt_errors) })
                end
              end
            end
          end

          def addresses_by_mode(mode, routing_table)
            case mode
            when READ
              routing_table.readers
            when WRITE
              routing_table.writers
            else
              raise unknown_mode mode
            end
          end

          def select_address(mode, addresses)
            case mode
            when READ
              @load_balancing_strategy.select_reader(addresses)
            when WRITE
              @load_balancing_strategy.select_writer(addresses)
            else
              raise unknown_mode mode
            end
          end

          def create_routing_tables(connection_pool, rediscovery, settings, clock, logging)
            RoutingTableRegistryImpl.new(connection_pool, rediscovery, clock, logging, settings.routing_table_purge_delay_ms)
          end

          def create_rediscovery(event_executor_group, initial_router, resolver, settings, clock, logging, domain_name_resolver)
            cluster_composition_provider = RoutingProcedureClusterCompositionProvider.new(clock, settings.routing_context)
            RediscoveryImpl.new(initial_router, settings, cluster_composition_provider, event_executor_group, resolver, logging, domain_name_resolver)
          end

          def unknown_mode(mode)
            ArgumentError.new("Mode '#{mode}' is not supported")
          end
        end
      end
    end
  end
end
