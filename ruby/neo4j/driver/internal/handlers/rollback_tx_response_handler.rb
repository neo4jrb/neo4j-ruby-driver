module Neo4j::Driver
  module Internal
    module Handlers
      class RollbackTxResponseHandler
        include Spi::ResponseHandler

        def initialize(rollback_future)
          @rollback_future = java.util.Objects.require_non_null(rollback_future)
        end

        def on_success(_metadata)
          @rollback_future.complete(nil)
        end

        def on_failure(error)
          @rollback_future.complete_exceptionally(error)
        end

        def on_record(fields)
          raise java.lang.UnsupportedOperationException, "Transaction rollback is not expected to receive records: #{fields}"
        end
      end
    end
  end
end
