module Neo4j::Driver
  module Internal
    module Async
      class InternalAsyncTransaction

        def initialize(tx)
          @tx = tx
        end

        delegate :commit_async, :rollback_async, :open?, :run_async, to: :@tx
      end
    end
  end
end
