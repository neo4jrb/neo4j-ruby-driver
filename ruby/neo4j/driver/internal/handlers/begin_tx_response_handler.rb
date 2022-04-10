module Neo4j::Driver
  module Internal
    module Handlers
      class BeginTxResponseHandler
        include Spi::ResponseHandler

        def initialize(begin_tx_future)
          @begin_tx_future = java.util.Objects.require_non_null(begin_tx_future)
        end

        def on_success(_metadata)
          @begin_tx_future.complete(nil)
        end

        def on_failure(error)
          @begin_tx_future.complete_exceptionally(error)
        end

        def on_record(fields)
          raise java.lang.UnsupportedOperationException, "Transaction begin is not expected to receive records: #{fields}"
        end
      end
    end
  end
end
