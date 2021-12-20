# frozen_string_literal: true

module Neo4j::Driver::Internal::Reactive
  class InternalRxTransaction
    include RxUtils

    def initialize(tx)
      @tx = tx
    end

    def run(query, opts)
      query = parse_query(query, opts)
      InternalRxResult.new do
        cursor_future = java.util.concurrent.CompletableFuture.new
        @tx.run_rx(query).when_complete do |cursor, completion_error|
          if cursor.nil?
            # We failed to create a result cursor so we cannot rely on result cursor to handle failure.
            # The logic here shall be the same as `TransactionPullResponseHandler#afterFailure` as that is where cursor handling failure
            # This is optional as tx still holds a reference to all cursor futures and they will be clean up properly in commit
            error = Util::Futures.completion_exception_cause(completion_error)
            @tx.mark_terminated(error)
            cursor_future.complete_exceptionally(error)
          else
            cursor_future.complete(cursor)
          end
        end
        cursor_future
      end
    end
  end

  def commit
    create_empty_publisher(&@tx.method(:commitAsync))
  end

  def rollback
    create_empty_publisher(&@tx.method(:rollbackAsync))
  end

  def close(commit = false)
    create_empty_publisher { @tx.close_async(commit) }
  end
end
