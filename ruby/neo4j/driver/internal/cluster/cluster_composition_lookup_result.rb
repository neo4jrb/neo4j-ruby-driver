module Neo4j::Driver
  module Internal
    module Cluster
      class ClusterCompositionLookupResult
        attr_reader :composition, :resolved_initial_routers

        def initialize(composition, resolved_initial_routers = nil)
          @composition = composition
          @resolved_initial_routers = resolved_initial_routers
        end
      end
    end
  end
end
