module Neo4j::Driver
  module Internal
    module Handlers
      class CommitTxResponseHandler
        include Spi::ResponseHandler

        def on_success(metadata)
          @bookmark = metadata['bookmark']&.then(&InternalBookmark.method(:parse))
        end

        def on_failure(error)
          raise error
        end

        def on_record(fields)
          raise "Transaction commit is not expected to receive records: #{fields}"
        end
      end
    end
  end
end
