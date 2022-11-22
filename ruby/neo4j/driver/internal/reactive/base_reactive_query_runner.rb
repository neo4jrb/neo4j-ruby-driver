module Neo4j::Driver
  module Internal
    module Reactive
      class BaseReactiveQueryRunner
        def run(query, **parameters)
          Query.new(query, **parameters)          
        end
      end
    end
  end
end
