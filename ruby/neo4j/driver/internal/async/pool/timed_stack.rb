module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class TimedStack < ConnectionPool::TimedStack
          def any_resource_busy?
            @mutex.synchronize do
              @created > @que.length
            end
          end
        end
      end
    end
  end
end
