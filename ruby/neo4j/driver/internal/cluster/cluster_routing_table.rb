module Neo4j::Driver
  module Internal
    module Cluster
      class ClusterRoutingTable
        MIN_ROUTERS = 1

        attr_reader :database_name

        def initialize(of_database, clock, routing_addresses)
          @database_name = of_database
          @clock = clock
          @expiration_timestamp = clock.millis - 1
          @routers = routing_addresses.freeze
          @table_lock = java.util.concurrent.locks.ReentrantReadWriteLock.new
          @prefer_initial_router = true
          @disused = {}
          @readers = []
          @writers = []
        end

        def stale_for?(mode)
          Util::LockUtil.execute_with_lock(@table_lock.read_lock) do
            @expiration_timestamp < @clock.millis ||
            routers.size < MIN_ROUTERS ||
            (mode == AccessMode::READ && @readers.size == 0) ||
            (mode == AccessMode::WRITE && @writers.size == 0)
          end
        end

        def has_been_stale_for?(extra_time)
          total_time = Util::LockUtil.execute_with_lock(@table_lock.read_lock, -> { @expiration_timestamp }) + extra_time

          total_time = java.lang.Long::MAX_VALUE if total_time < 0

          total_time < @clock.millis
        end

        def update(cluster)
          Util::LockUtil.execute_with_lock(@table_lock.write_lock) do
            @expiration_timestamp = cluster.expiration_timestamp
            @readers = new_with_reused_addresses(@readers, @disused, cluster.readers)
            @writers = new_with_reused_addresses(@writers, @disused, cluster.writers)
            @routers = new_with_reused_addresses(@routers, @disused, cluster.routers)
            @disused.clear
            @prefer_initial_router = !cluster.has_writers?
          end
        end

        def forget(address)
          Util::LockUtil.execute_with_lock(@table_lock.write_lock) do
            @routers = new_without_address_if_present(@routers, address)
            @readers = new_without_address_if_present(@readers, address)
            @writers = new_without_address_if_present(@writers, address)
            @disused << address
          end
        end

        def readers
          Util::LockUtil.execute_with_lock(@table_lock.read_lock, -> { @readers })
        end

        def writers
          Util::LockUtil.execute_with_lock(@table_lock.read_lock, -> { @writers })
        end

        def routers
          Util::LockUtil.execute_with_lock(@table_lock.read_lock, -> { @routers })
        end

        def servers
          Util::LockUtil.execute_with_lock(@table_lock.write_lock) do
            servers = []
            servers << (@readers)
            servers << (@writers)
            servers << (@routers)
            servers << (@disused)
          end
        end

        def forget_writer(to_remove)
          Util::LockUtil.execute_with_lock(@table_lock.write_lock) do
            @writers = new_without_address_if_present(@writers, to_remove)
            @disused << to_remove
          end
        end

        def replace_router_if_present(old_router, new_router)
          Util::LockUtil.execute_with_lock(@table_lock.write_lock, -> { @routers = new_with_address_replaced_if_present(@routers, old_router, new_router) } )
        end

        def prefer_initial_router
          Util::LockUtil.execute_with_lock(@table_lock.read_lock, -> { @prefer_initial_router })
        end

        def expiration_timestamp
          Util::LockUtil.execute_with_lock(@table_lock.read_lock, -> { @expiration_timestamp })
        end

        def to_s
          Util::LockUtil.execute_with_lock(@table_lock.read_lock) do
            "Ttl #{@expiration_timestamp}, currentTime #{@clock.millis}, routers #{@routers}, writers #{@writers}, readers #{@readers}, database '#{database_name.description}'"
          end
        end

        private

        def new_without_address_if_present(addresses, address_to_skip)
          new_list = []

          addresses.each do |address|
            new_list << address unless address.eql?(address_to_skip)
          end

          new_list.freeze
        end

        def new_with_address_replaced_if_present(addresses, old_address, new_address)
          new_list = []

          addresses.each { |address| new_list << address.eql?(old_address) ? new_address : address }

          new_list.freeze
        end

        def new_with_reused_addresses(current_addresses, disused_addresses, new_addresses)
          new_list = java.util.stream.Stream.concat(current_addresses.stream, disused_addresses.stream)
                                            .filter(-> (address) { new_addresses.remove(to_bolt_server_address(address)) })
                                            .collect(java.util.stream.Collectors.to_collection(-> { Array.new(new_addresses.size) }))
          new_list << new_addresses
          new_list.freeze
        end

        def to_bolt_server_address(address)
          BoltServerAddress.class.eql?(address.class) ? address : BoltServerAddress.new(address.host, address.port)
        end
      end
    end
  end
end
