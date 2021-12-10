module Neo4j::Driver
  module Internal
    module Async
      class InternalAsyncTransaction

        def initialize(tx)
          @tx = tx
        end

        delegate :commit_async, :rollback_async, :open?, to: :@tx

        def run_async(query)
          @tx.run_async(query)
        end
      end
    end
  end
end
