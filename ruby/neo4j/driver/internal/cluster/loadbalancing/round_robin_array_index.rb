module Neo4j::Driver
  module Internal
    module Cluster
      module Loadbalancing
        class RoundRobinArrayIndex < Concurrent::AtomicFixnum
          def next(array_length)
            (increment - 1) % array_length if array_length.positive?
          end
        end
      end
    end
  end
end
