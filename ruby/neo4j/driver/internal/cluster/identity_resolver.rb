module Neo4j::Driver
  module Internal
    module Cluster
      class IdentityResolver
        IDENTITY_RESOLVER = new

        def resolve(initial_router)
          java.util.Collections.singleton(initial_router)
        end
      end
    end
  end
end
