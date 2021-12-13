module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class ConnectionPoolImpl
          attr_reader :connector, :bootstrap, :netty_channel_tracker, :channel_health_checker, :settings,
                      :log, :metrics_listener, :owns_event_loop_group, :address_to_pool_lock, :address_to_pool,
                      :closed, :close_future, :connection_factory

          def initialize(connector, bootstrap, settings, metrics_listener, logging, clock, owns_event_loop_group,
                         netty_channel_tracker = nil, netty_channel_health_checker = nil, connection_factory = nil)
            @connector = connector
            @bootstrap = bootstrap
            @netty_channel_tracker = NettyChannelTracker.new(metrics_listener, bootstrap.config.group.next, logging)
            @channel_health_checker = NettyChannelHealthChecker.new(settings, clock, logging)
            @settings = settings
            @metrics_listener = metrics_listener
            @log = logging.get_log(self.class)
            @owns_event_loop_group = owns_event_loop_group
            @connection_factory = NetworkConnectionFactory.new(clock, metrics_listener, logging)
          end

          def acquire(address)
            log.trace("Acquiring a connection from pool towards #{address}")

            assert_not_closed
            pool = get_or_create_pool(address)
            acquire_event = metrics_listener.create_listener_event
            metrics_listener.before_acquiring_or_creating(pool.id, acquire_event)
            channel_future = pool.acquire

            channel_future.handle do |channel, error|
              begin
                process_acquisition_error(pool, address, error)
                assert_not_closed(address, channel, pool)
                Connection::ChannelAttributes.set_authorization_state_listener(channel, channel_health_checker)
                connection = connection_factory.create_connection(channel, pool)

                metrics_listener.after_acquired_or_created(pool.id, acquire_event)
                connection
              ensure
                metrics_listener.after_acquiring_or_creating(pool.id)
              end
            end
          end

          def retain_all(addresses_to_retain)
            Util::LockUtil.execute_with_lock(address_to_pool_lock) do
                entry_iterator = address_to_pool.entry_set.iterator
                entry_iterator.each do |iterator|
                  address = iterator.get_key
                  if !addresses_to_retain.contains(address)
                    active_channels = netty_channel_tracker.in_use_channel_count(address)
                    if active_channels == 0
                      # address is not present in updated routing table and has no active connections
                      # it's now safe to terminate corresponding connection pool and forget about it
                      pool = iterator.get_value
                      entry_iterator.remove

                      unless pool.nil?
                        log.info("Closing connection pool towards #{address}, it has no active connections and is not in the routing table registry.")
                        close_pool_in_background(address, pool)
                      end
                    end
                  end
                end
              end
          end

          def in_use_connections(address)
            netty_channel_tracker.in_use_channel_count(address)
          end

          def idle_connections(address)
            netty_channel_tracker.idle_channel_count(address)
          end

          def close
            if closed.compare_and_set(false, true)
              netty_channel_tracker.prepare_to_close_channels

              Util::LockUtil.execute_with_lock_async(address_to_pool_lock.write_lock) do
                # We can only shutdown event loop group when all netty pools are fully closed,
                # otherwise the netty pools might missing threads (from event loop group) to execute clean ups.
                close_all_pools.when_complete do |_ignored, poll_close_error|
                  address_to_pool.clear
                  if !owns_event_loop_group
                    Util::Futures.complete_with_null_if_no_error(close_future, poll_close_error)
                  else
                    shutdown_event_loop_group(poll_close_error)
                  end
                end
              end
            end
            close_future
          end

          def is_open?(address)
            Util::LockUtil.execute_with_lock(address_to_pool_lock.read_lock, -> () {address_to_pool.contains_key(address)})
          end

          def to_string
            Util::LockUtil.execute_with_lock(address_to_pool_lock.read_lock) { "ConnectionPoolImpl{ pools=#{address_to_pool}}" }
          end

          private

          def process_acquisition_error(pool, server_address, error)
            cause = Util::Futures.completion_exception_cause(error)

            if !cause.nil?
              if cause.is_a?(java.util.concurrent.TimeoutException)
                # NettyChannelPool returns future failed with TimeoutException if acquire operation takes more than
                # configured time, translate this exception to a prettier one and re-throw
                metrics_listener.after_timed_out_to_acquire_or_create(pool.id)
                raise Neo4j::Driver::Exceptions::ClientException.new("Unable to acquire connection from the pool within configured maximum time of #{settings.connection_acquisition_timeout}ms")
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
            if closed.get
              unless address.nil?
                pool.release(channel)
                close_pool_in_background(address, pool)
                Util::LockUtil.execute_with_lock(address_to_pool_lock.write_lock, -> (){ address_to_pool.remove(address) })
              end
              java.lang.IllegalStateException.new(Spi::ConnectionPool::CONNECTION_POOL_CLOSED_ERROR_MESSAGE)
            end
          end

          # for testing only
          def get_pool(address)
            Util::LockUtil.execute_with_lock(address_to_pool_lock.read_lock) do
              address_to_pool.get(address)
            end
          end

          def new_pool(address)
            NettyChannelPool.new(address, connector, bootstrap, netty_channel_tracker, channel_health_checker,
                                 settings.connection_acquisition_timeout, settings.max_connection_pool_size)
          end

          def get_or_create_pool(address)
            existing_pool = Util::LockUtil.execute_with_lock(address_to_pool_lock.read_lock, -> () { address_to_pool.get(address) })

            if !existing_pool.nil?
              existing_pool
            else
              Util::LockUtil.execute_with_lock(address_to_pool_lock.write_lock) do
                pool = new_pool(address)
                if pool.nil?
                  # before the connection pool is added I can add the metrics for the pool.
                  metrics_listener.put_pool_metrics(pool.id, address, self)
                  address_to_pool.put(address, pool)
                end
                pool
              end
            end
          end

          def close_pool(pool)
            pool.close.when_complete do |_ignored, error|
              # after the connection pool is removed/close, I can remove its metrics.
              metrics_listener.remove_pool_metrics(pool.id)
            end
          end

          def close_pool_in_background(address, pool)
            # Close in the background
            close_pool(pool).when_complete do |_ignored, error|
              unless error.nil?
                log.warn( format("An error occurred while closing connection pool towards #{address}."), error)
              end
            end
          end

          def event_loop_group
            bootstrap.config.group
          end

          def shutdown_event_loop_group(poll_close_error)
            # This is an attempt to speed up the shut down procedure of the driver
            # This timeout is needed for `closePoolInBackground` to finish background job, especially for races between `acquire` and `close`.
            event_loop_group.shutdown_gracefully(200, 15_000, java.util.concurrent.TimeUnit.MILLISECONDS)
            Util::Futures.as_completion_stage(event_loop_group, termination_future).when_complete do |_ignore, event_loop_group_termination_error|
              combined_errors = Util::Futures.combined_errors(poll_close_error, eventLoopGroupTerminationError)
              Util::Futures.complete_with_null_if_no_error(close_future, combined_errors)
            end
          end

          def close_all_pools
            java.util.concurrent.CompletableFuture.all_of(
                address_to_pool.entry_set.stream.map do |entry|
                  address = entry.get_key
                  pool = entry.get_value
                  # Wait for all pools to be closed.
                  close_pool(pool).to_completable_future
                end
              ).java.util.concurrent.CompletableFuture.new
          end
        end
      end
    end
  end
end
