module Neo4j::Driver
  module Internal
    module Handlers
      class CommitTxResponseHandler
        include Spi::ResponseHandler

        def initialize(commit_future)
          @commit_future = java.util.Objects.require_non_null(commit_future)
        end

        def on_success(metadata)
          bookmark_value = metadata['bookmark']

          if bookmark_value.nil?
            @commit_future.complete(nil)
          else
            @commit_future.complete(InternalBookmark.parse(bookmark_value))
          end
        end

        def on_failure(error)
          @commit_future.complete_exceptionally(error)
        end

        def on_record(fields)
          raise java.lang.UnsupportedOperationException, "Transaction commit is not expected to receive records: #{fields}"
        end
      end
    end
  end
end
