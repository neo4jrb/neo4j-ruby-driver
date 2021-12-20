# frozen_string_literal: true

module Neo4j::Driver::Internal::Reactive
  class InternalRxSession
    include RxUtils

    delegate :last_bookmark, to: :@session

    def initialize(session)
      # RxSession accept a network session as input.
      # The network session different from async session that it provides ways to both run for Rx and Async
      # Note: Blocking result could just build on top of async result. However Rx result cannot just build on top of async result.
      @session = session
    end

    def begin_transaction(mode: nil, config: Neo4j::Driver::TransactionConfig.empty)
      create_single_item_publisher(
        lambda do
          tx_future = java.util.concurrent.CompletableFuture.new
          @session.begin_transaction_async([mode, config].compact!).when_complete do |tx, completion_error|
            if tx.nil?
              release_connection_before_returning(tx_future, completion_error)
            else
              tx_future.complete(InternalRxTransaction.new(tx))
            end
          end
          tx_future
        end,
        lambda do
          Neo4j::Driver::Exceptions::IllegalStateException.new(
            'Unexpected condition, begin transaction call has completed successfully with transaction being null'
          )
        end
      )
    end

    def read_transaction(work, config = Neo4j::Driver::TransactionConfig.empty)
      run_transaction(Neo4j::Driver::AccessMode::READ, work, config)
    end

    def write_transaction(work, config = Neo4j::Driver::TransactionConfig.empty)
      run_transaction(Neo4j::Driver::AccessMode::WRITE, work, config)
    end

    def run(query, opts = {}, config: Neo4j::Driver::TransactionConfig.empty)
      query = parse_query(query, opts)
      InternalRxResult.new do
        result_cursor_future = new java.util.concurrent.CompletableFuture()
        @session.run_rx(query, config).when_complete do |cursor, completion_error|
          if cursor
            result_cursor_future.complete(cursor)
          else
            release_connection_before_returning(result_cursor_future, completion_error)
          end
        end
        result_cursor_future
      end
    end

    private

    def run_transaction(mode, work, config)
      repeatable_work = org.neo4j.driver.internal.shaded.reactor.core.publisher.Flux.using_when(
        begin_transaction(mode: mode, config: config),
        work.method(:execute),
        ->(tx) { tx.close(true) },
        ->(tx, _error) { tx.close },
        InternalRxTransaction.method(:close)
      )
      @session.retry_logic.retry_rx(repeatable_work)
    end

    def release_connection_before_returning(return_future, completion_error)
      # We failed to create a result cursor so we cannot rely on result cursor to cleanup resources.
      # Therefore we will first release the connection that might have been created in the session and then notify the error.
      # The logic here shall be the same as `SessionPullResponseHandler#afterFailure`.
      # The reason we need to release connection in session is that we made `rxSession.close()` optional;
      # Otherwise, session.close shall handle everything for us.

      error = Util::Futures.completion_exception_cause(completion_error)
      if error.is_a?(Neo4j::Driver::Exceptions::TransactionNestingException)
        return_future.complete_exceptionally(error)
      else
        @session.release_connection_async.when_complete do |_, close_error|
          return_future.complete_exceptionally(Util::Futures.combine_errors(error, close_error))
        end
      end
    end

    def reset
      create_empty_publisher(&@session.method(:reset_async))
    end

    def close
      create_empty_publisher(&@session.method(:close_async))
    end
  end
end
