module Neo4j::Driver
  module Internal
    module Async
      class InternalAsyncTransaction
        delegate :run_async, :commit_async, :rollback_async, :open?, to: :@tx

        def initialize(tx)
          @tx = tx
        end
      end
    end
  end
end
