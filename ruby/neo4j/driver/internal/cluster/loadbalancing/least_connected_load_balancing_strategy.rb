module Neo4j::Driver
  module Internal
    module Cluster
      module Loadbalancing

        # Load balancing strategy that finds server with the least amount of active (checked out of the pool) connections from given readers or writers. It finds a
        # start index for iteration in a round-robin fashion. This is done to prevent choosing same first address over and over when all addresses have the same amount
        # of active connections.
        class LeastConnectedLoadBalancingStrategy

          def initialize(connection_pool, logger)
            @readers_index = RoundRobinArrayIndex.new
            @writers_index = RoundRobinArrayIndex.new

            @connection_pool = connection_pool
            @log = logger
          end

          def select_reader(known_readers)
            select(known_readers, @readers_index, 'reader')
          end

          def select_writer(known_writers)
            select(known_writers, @writers_index, 'writer')
          end

          private

          def select(addresses, addresses_index, address_type)
            size = addresses.size

            if size == 0
              @log.trace("Unable to select #{address_type}, no known addresses given")
              return nil
            end

            # choose start index for iteration in round-robin fashion
            start_index = addresses_index.next(size)
            index = start_index

            least_connected_address = nil
            least_active_connections = java.lang.Integer::MAX_VALUE

            # iterate over the array to find the least connected address
            loop do
              address = addresses[index]
              active_connections = @connection_pool.in_use_connections(address)

              if active_connections < least_active_connections
                least_connected_address = address
                least_active_connections = active_connections
              end

              # loop over to the start of the array when end is reached
              index = (index == size - 1) ? 0 : index += 1

              break if index != start_index
            end

            @log.trace("Selected #{address_type} with address: '#{least_connected_address}' and active connections: #{least_active_connections}")

            least_connected_address
          end
        end
      end
    end
  end
end
