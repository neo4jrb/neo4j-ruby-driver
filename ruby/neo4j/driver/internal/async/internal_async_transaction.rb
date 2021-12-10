module Neo4j::Driver
  module Internal
    module Async
      class InternalAsyncTransaction
        attr_reader :tx

        def initialize(tx)
          @tx = tx
        end

        def commit_async
          tx.commit_async
        end

        def rollback_async
          tx.rollback_async
        end
      end
    end
  end
end
