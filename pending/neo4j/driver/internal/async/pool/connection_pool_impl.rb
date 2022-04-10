module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class ConnectionPoolImpl
          def initialize(connector, bootstrap, settings, metrics_listener, logger, clock, owns_event_loop_group,
                         netty_channel_tracker = nil, netty_channel_health_checker = nil, connection_factory = nil)
            @connector = connector
            @bootstrap = bootstrap
            # @netty_channel_tracker = NettyChannelTracker.new(metrics_listener, bootstrap.config.group.next, logger)
            # @channel_health_checker = NettyChannelHealthChecker.new(settings, clock, logger)
            @settings = settings
            @metrics_listener = metrics_listener
            @log = logger
            @owns_event_loop_group = owns_event_loop_group
            @connection_factory = NetworkConnectionFactory.new(clock, metrics_listener, logger)

            @address_to_pool_lock = Concurrent::ReentrantReadWriteLock.new
            @address_to_pool = {}
            @closed = Concurrent::AtomicBoolean.new
            @close_future = Concurrent::Promises.resolvable_future
          end

          def acquire(address)
            @log.debug("Acquiring a connection from pool towards #{address}")

            assert_not_closed
            pool = get_or_create_pool(address)
            acquire_event = @metrics_listener.create_listener_event
            @metrics_listener.before_acquiring_or_creating(pool.object_id, acquire_event)
            channel_future = pool.acquire

            channel_future.chain do |_fulfilled, channel, error|
              process_acquisition_error(pool, address, error)
              assert_not_closed(address, channel, pool)
              Connection::ChannelAttributes.set_authorization_state_listener(channel, @channel_health_checker)
              connection = @connection_factory.create_connection(channel, pool)

              @metrics_listener.after_acquired_or_created(pool.id, acquire_event)
              connection
            ensure
              @metrics_listener.after_acquiring_or_creating(pool.id)
            end
          end

          def retain_all(addresses_to_retain)
            @address_to_pool_lock.with_write_lock do
              @address_to_pool.each do |address, pool|
                unless addresses_to_retain.include?(address)
                  active_channels = @netty_channel_tracker.in_use_channel_count(address)
                  if active_channels.zero?
                    # address is not present in updated routing table and has no active connections
                    # it's now safe to terminate corresponding connection pool and forget about it
                    @address_to_pool.delete(address)
                    if pool
                      @log.info("Closing connection pool towards #{address}, it has no active connections and is not in the routing table registry.")
                      close_pool_in_background(address, pool)
                    end
                  end
                end
              end
            end
          end

          def in_use_connections(address)
            @netty_channel_tracker.in_use_channel_count(address)
          end

          def idle_connections(address)
            @netty_channel_tracker.idle_channel_count(address)
          end

          def close
            if @closed.make_true
              # @netty_channel_tracker.prepare_to_close_channels

              @address_to_pool_lock.with_write_lock do
                # We can only shutdown event loop group when all netty pools are fully closed,
                # otherwise the netty pools might missing threads (from event loop group) to execute clean ups.
                close_all_pools.on_resolution do |_fulfilled, _value, poll_close_error|
                  @address_to_pool.clear
                  if @owns_event_loop_group
                    shutdown_event_loop_group(poll_close_error)
                  else
                    Util::Futures.complete_with_null_if_no_error(@close_future, poll_close_error)
                  end
                end
              end
            end
            @close_future
          end

          def open?(address)
            @address_to_pool_lock.with_read_lock { @address_to_pool.key?(address) }
          end

          def to_string
            @address_to_pool_lock.with_read_lock { "ConnectionPoolImpl{ pools=#{@address_to_pool}}" }
          end

          private

          def process_acquisition_error(pool, server_address, error)
            if error.nil
              if error.is_a?(java.util.concurrent.TimeoutException)
                # NettyChannelPool returns future failed with TimeoutException if acquire operation takes more than
                # configured time, translate this exception to a prettier one and re-throw
                metrics_listener.after_timed_out_to_acquire_or_create(pool.id)
                raise Neo4j::Driver::Exceptions::ClientException.new("Unable to acquire connection from the pool within configured maximum time of #{@settings.connection_acquisition_timeout}ms")
              elsif pool.is_closed?
                # There is a race condition where a thread tries to acquire a connection while the pool is closed by another concurrent thread.
                # Treat as failed to obtain connection for a direct driver. For a routing driver, this error should be retried.
                raise Neo4j::Driver::Exceptions::ServiceUnavailableException.new(format("Connection pool for server #{server_address} is closed while acquiring a connection."), cause)
              else
                # some unknown error happened during connection acquisition, propagate it
                raise java.util.concurrent.CompletionException.new(cause)
              end
            end
          end

          def assert_not_closed(address = nil, channel = nil, pool = nil)
            if @closed.true?
              if address
                pool.release(channel)
                close_pool_in_background(address, pool)
                @address_to_pool_lock.with_write_lock { @address_to_pool.delete(address) }
              end
              raise Exceptions::IllegalStateException, Spi::ConnectionPool::CONNECTION_POOL_CLOSED_ERROR_MESSAGE
            end
          end

          # for testing only
          protected def pool(address)
            @address_to_pool_lock.with_read_lock { @address_to_pool[address] }
          end

          class Connection < ::Async::Pool::Resource
            attr :version, true
            attr :io

            def initialize(address)
              super()
              @io = ::Async::IO::Endpoint.tcp(address.host, address.port).connect
            end

            def close
              super
              @io.close
            end
          end

          def new_pool(address)
            ::Async::Pool::Controller.wrap { Connection.new(address) }
          end

          def get_or_create_pool(address)
            @address_to_pool_lock.with_read_lock { @address_to_pool[address] } ||
              @address_to_pool_lock.with_write_lock do
                new_pool(address)&.tap do |pool|
                  # before the connection pool is added I can add the metrics for the pool.
                  @metrics_listener.put_pool_metrics(pool.object_id, address, self)
                  @address_to_pool[address] = pool
                end
              end
          end

          def close_pool(pool)
            pool.close.wait
            # after the connection pool is removed/close, I can remove its metrics.
            @metrics_listener.remove_pool_metrics(pool.object_id)
          end

          def close_pool_in_background(address, pool)
            # Close in the background
            close_pool(pool).on_rejection do |error|
              @log.warn("An error occurred while closing connection pool towards #{address}.", error)
            end
          end

          def event_loop_group
            @bootstrap.config.group
          end

          def shutdown_event_loop_group(poll_close_error)
            # This is an attempt to speed up the shut down procedure of the driver
            # This timeout is needed for `closePoolInBackground` to finish background job, especially for races between `acquire` and `close`.
            @event_loop_group.shutdown_gracefully(200, 15.seconds)
            @event_loop_group.termination_future.on_completion do |_fulfilled, _value, event_loop_group_termination_error|
              combined_errors = Util::Futures.combined_errors(poll_close_error, event_loop_group_termination_error)
              Util::Futures.complete_with_null_if_no_error(@close_future, combined_errors)
            end
          end

          def close_all_pools
            Concurrent::Promises.zip_futures(
              *@address_to_pool.map do |address, pool|
                @log.info("Closing connection pool towards #{address}")
                # Wait for all pools to be closed.
                close_pool(pool)
              end
            )
          end
        end
      end
    end
  end
end
