module Neo4j::Driver
  module Internal
    module Handlers
      class CommitTxResponseHandler
        include Spi::ResponseHandler

        def initialize(result_holder)
          @result_holder = result_holder
        end

        def on_success(metadata)
          @result_holder.succeed(metadata[:bookmark]&.then(&InternalBookmark.method(:parse)))
        end

        def on_failure(error)
          @result_holder.fail(error)
        end

        def on_record(fields)
          raise "Transaction commit is not expected to receive records: #{fields}"
        end
      end
    end
  end
end
