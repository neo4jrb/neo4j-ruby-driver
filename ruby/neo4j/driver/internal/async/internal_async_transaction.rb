module Neo4j::Driver
  module Internal
    module Async
      class InternalAsyncTransaction

        def initialize(tx)
          @tx = tx
        end

        def commit_async
          @tx.commit_async
        end

        def rollback_async
          @tx.rollback_async
        end

        def run_async(query)
          @tx.run_async(query)
        end

        def is_open?
          @tx.is_open?
        end
      end
    end
  end
end
