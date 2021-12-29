module Neo4j::Driver
  module Internal
    module Cluster
      module Loadbalancing
        class RoundRobinArrayIndex

          # only for testing
          def initialize(initial_offset = 0)
            @offset = java.util.concurrent.atomic.AtomicInteger.new(initial_offset)
          end

          def next(array_length)
            return nil if array_length == 0

            while @offset.get_and_increment < 0
              next_offset = @offset.get_and_increment

              # overflow, try resetting back to zero
              @offset.compare_and_set(next_offset + 1, 0)
            end

            next_offset % array_length
          end
        end
      end
    end
  end
end
