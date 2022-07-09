module Neo4j::Driver
  module Internal
    module Cluster
      class ClusterCompositionLookupResult
        attr_reader :cluster_composition, :resolved_initial_routers

        def initialize(composition, resolved_initial_routers = nil)
          @cluster_composition = composition
          @resolved_initial_routers = resolved_initial_routers
        end
      end
    end
  end
end
