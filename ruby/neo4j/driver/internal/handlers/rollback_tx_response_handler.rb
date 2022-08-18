module Neo4j::Driver
  module Internal
    module Handlers
      class RollbackTxResponseHandler
        include Spi::ResponseHandler

        def initialize(result_holder)
          @result_holder = result_holder
        end

        def on_success(_metadata)
          @result_holder.succeed
        end

        def on_failure(error)
          @result_holder.fail(error)
        end

        def on_record(fields)
          raise "Transaction rollback is not expected to receive records: #{fields}"
        end
      end
    end
  end
end
