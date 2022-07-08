module Neo4j::Driver
  module Internal
    module Cluster
      class ClusterRoutingTable
        MIN_ROUTERS = 1

        def initialize(of_database, clock, *routing_addresses)
          @database_name = of_database
          @clock = clock
          @expiration_timestamp = clock.millis - 1
          @routers = routing_addresses.freeze
          @table_lock = Concurrent::ReentrantReadWriteLock.new
          @prefer_initial_router = true
          @disused = Set.new
          @readers = []
          @writers = []
        end

        def stale_for?(mode)
          @table_lock.with_read_lock do
            @expiration_timestamp < @clock.millis ||
              routers.size < MIN_ROUTERS ||
              (mode == AccessMode::READ && @readers.size == 0) ||
              (mode == AccessMode::WRITE && @writers.size == 0)
          end
        end

        def has_been_stale_for?(extra_time)
          total_time = @table_lock.with_read_lock { @expiration_timestamp } + extra_time
          total_time < @clock.millis
        end

        def update(cluster)
          @table_lock.with_write_lock do
            @expiration_timestamp = cluster.expiration_timestamp
            @readers = new_with_reused_addresses(@readers, @disused, cluster.readers)
            @writers = new_with_reused_addresses(@writers, @disused, cluster.writers)
            @routers = new_with_reused_addresses(@routers, @disused, cluster.routers)
            @disused.clear
            @prefer_initial_router = !cluster.has_writers?
          end
        end

        def forget(address)
          @table_lock.with_write_lock do
            @routers = new_without_address_if_present(@routers, address)
            @readers = new_without_address_if_present(@readers, address)
            @writers = new_without_address_if_present(@writers, address)
            @disused << address
          end
        end

        def readers
          @table_lock.with_read_lock { @readers }
        end

        def writers
          @table_lock.with_read_lock { @writers }
        end

        def routers
          @table_lock.with_read_lock { @routers }
        end

        def servers
          @table_lock.with_write_lock do
            [@readers, @writers, @routers, @disused].flatten.to_set
          end
        end

        def database
          @database_name
        end

        def forget_writer(to_remove)
          Util::LockUtil.execute_with_lock(@table_lock.write_lock) do
            @writers = new_without_address_if_present(@writers, to_remove)
            @disused << to_remove
          end
        end

        def replace_router_if_present(old_router, new_router)
          @table_lock.with_write_lock { @routers = new_with_address_replaced_if_present(@routers, old_router, new_router) }
        end

        def prefer_initial_router
          @table_lock.with_read_lock { @prefer_initial_router }
        end

        def expiration_timestamp
          @table_lock.with_read_lock { @expiration_timestamp }
        end

        def to_s
          @table_lock.with_read_lock do
            "Ttl #{@expiration_timestamp}, currentTime #{@clock.millis}, routers #{@routers}, writers #{@writers}, readers #{@readers}, database '#{@database_name.description}'"
          end
        end

        private

        def new_without_address_if_present(addresses, address_to_skip)
          (addresses - [address_to_skip]).freeze
        end

        def new_with_address_replaced_if_present(addresses, old_address, new_address)
          addresses.map { |address| address == old_address ? new_address : address }.freeze
        end

        def new_with_reused_addresses(current_addresses, disused_addresses, new_addresses)
          (current_addresses.to_set + disused_addresses + new_addresses).to_a.freeze
        end

        def to_bolt_server_address(address)
          if BoltServerAddress.class == address.class
            address
          else
            BoltServerAddress.new(host: address.host, port: address.port)
          end
        end
      end
    end
  end
end
