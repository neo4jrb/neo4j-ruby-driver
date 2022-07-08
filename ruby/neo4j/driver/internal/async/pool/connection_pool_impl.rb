module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class ConnectionPoolImpl
          def initialize(connector, settings, logger)
            @connector = connector
            @settings = settings
            @log = logger
            @address_to_pool_lock = Concurrent::ReentrantReadWriteLock.new
            @address_to_pool = {}
            @closed = Concurrent::AtomicBoolean.new
          end

          def acquire(address)
            @log.debug("Acquiring a connection from pool towards #{address}")

            assert_not_closed
            pool = get_or_create_pool(address)

            begin
              channel = pool.acquire
              @log.debug{"Channel #{channel.object_id} acquired"}
            rescue => error
              process_acquisition_error(pool, address, error)
            end
            assert_not_closed(address, channel, pool)
            NetworkConnection.new(channel, pool, @log)
          end

          def retain_all(addresses_to_retain)
            @address_to_pool_lock.with_write_lock do
              @address_to_pool.each do |address, pool|
                unless addresses_to_retain.include?(address)
                  unless pool.busy?
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
            @address_to_pool[address]&.size || 0
            # @netty_channel_tracker.in_use_channel_count(address)
          end

          def idle_connections(address)
            @netty_channel_tracker.idle_channel_count(address)
          end

          def close
            if @closed.make_true
              @address_to_pool_lock.with_write_lock do
                # We can only shutdown event loop group when all netty pools are fully closed,
                # otherwise the netty pools might missing threads (from event loop group) to execute clean ups.
                close_all_pools
                @address_to_pool.clear
              end
            end
          end

          def open?(address)
            @address_to_pool_lock.with_read_lock { @address_to_pool.key?(address) }
          end

          def to_string
            @address_to_pool_lock.with_read_lock { "ConnectionPoolImpl{ pools=#{@address_to_pool}}" }
          end

          private

          def process_acquisition_error(pool, server_address, error)
            if error.is_a?(::Async::TimeoutError)
              # NettyChannelPool returns future failed with TimeoutException if acquire operation takes more than
              # configured time, translate this exception to a prettier one and re-throw
              raise Neo4j::Driver::Exceptions::ClientException.new("Unable to acquire connection from the pool within configured maximum time of #{@settings.connection_acquisition_timeout.inspect}")
            # elsif pool.closed?
              # There is a race condition where a thread tries to acquire a connection while the pool is closed by another concurrent thread.
              # Treat as failed to obtain connection for a direct driver. For a routing driver, this error should be retried.
              # raise Neo4j::Driver::Exceptions::ServiceUnavailableException, "Connection pool for server #{server_address} is closed while acquiring a connection."
            else
              # some unknown error happened during connection acquisition, propagate it
              raise error
            end
          end

          def assert_not_closed(address = nil, channel = nil, pool = nil)
            if @closed.true?
              if address
                pool.release(channel)
                close_pool_in_background(address, pool)
                @address_to_pool_lock.with_write_lock { @address_to_pool.delete(address) }
                assert_not_closed
              end
              raise Exceptions::IllegalStateException, Spi::ConnectionPool::CONNECTION_POOL_CLOSED_ERROR_MESSAGE
            end
          end

          # for testing only
          protected def pool(address)
            @address_to_pool_lock.with_read_lock { @address_to_pool[address] }
          end

          def new_pool(address)
            Controller.wrap(limit: @settings.max_connection_pool_size, acquisition_timeout: @settings.connection_acquisition_timeout) { Channel.new(address, @connector, @log) }
          end

          def get_or_create_pool(address)
            @address_to_pool_lock.with_read_lock { @address_to_pool[address] } ||
              @address_to_pool_lock.with_write_lock do
                new_pool(address)&.tap do |pool|
                  # before the connection pool is added I can add the metrics for the pool.
                  # @metrics_listener.put_pool_metrics(pool.object_id, address, self)
                  @address_to_pool[address] = pool
                end
              end
          end

          def close_pool(pool)
            pool.close
          end

          def close_pool_in_background(address, pool)
            Async do
              # Close in the background
              close_pool(pool)
            rescue => error
              @log.warn("An error occurred while closing connection pool towards #{address}.", error)
            end
          end

          def close_all_pools
            @address_to_pool.map do |address, pool|
              @log.info("Closing connection pool towards #{address}")
              # Wait for all pools to be closed.
              close_pool(pool)
            end
          end
        end
      end
    end
  end
end
