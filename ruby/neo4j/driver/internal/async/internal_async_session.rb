module Neo4j::Driver
  module Internal
    module Async
      class InternalAsyncSession
        def initialize(session)
          @session = session
        end

        delegate :last_bookmark, :close_async, to: :@session

        def run_async(query, parameters = {}, config = {})
          @session.run_async(org.neo4j.driver.Query.new(query, **parameters), **config)
        end

        def begin_transaction_async(**config)
          @session.begin_transaction_async(**config).then_apply(&InternalAsyncTransaction.method(:new))
        end

        def read_transaction_async(**config, &work)
          transaction_async(org.neo4j.driver.AccessMode::READ, **config, &work)
        end

        def write_transaction_async(**config, &work)
          transaction_async(org.neo4j.driver.AccessMode::WRITE, **config, &work)
        end

        private

        def transaction_async(mode, **config, &work)
          @session.retry_logic.retry_async do
            result_future = java.util.concurrent.CompletableFuture.new
            tx_future = @session.begin_transaction_async(mode, **config)

            tx_future.when_complete do |tx, completion_error|
              error = Util::Futures.completion_exception_cause(completion_error)

              if !error.nil?
                result_future.complete_exceptionally(error)
              else
                execute_work(result_future, tx, &work)
              end
            end
            result_future
          end
        end

        def execute_work(result_future, tx, &work)
          work_future = safe_execute_work(tx, &work)

          work_future.when_complete do |result, completion_error|
            error = Util::Futures.completion_exception_cause(completion_error)

            if !error.nil?
              close_tx_after_failed_transaction_work(tx, result_future, error)
            else
              close_tx_after_succeeded_transaction_work(tx, result_future, result)
            end
          end
        end

        def safe_execute_work(tx)
          # given work might fail in both async and sync way
          # async failure will result in a failed future being returned
          # sync failure will result in an exception being thrown
          begin
            result = yield InternalAsyncTransaction.new(tx)

            # protect from given transaction function returning null
            result == nil ? Util::Futures.completed_with_null : result
          rescue StandardError => work_error
            # work threw an exception, wrap it in a future and proceed
            Util::Futures.failed_future(work_error)
          end
        end

        def close_tx_after_failed_transaction_work(tx, result_future, error)
          tx.close_async.when_complete do |_ignored, rollback_error|
            error.add_suppressed(rollback_error) unless rollback_error.nil?

            result_future.complete_exceptionally(error)
          end
        end

        def close_tx_after_succeeded_transaction_work(tx, result_future, result)
          tx.close_async(true).when_complete do |_ignored, completion_error|
            commit_error = Util::Futures.completion_exception_cause(completion_error)

            if !commit_error.nil?
              result_future.complete_exceptionally(commit_error)
            else
              result_future.complete(result)
            end
          end
        end
      end
    end
  end
end
