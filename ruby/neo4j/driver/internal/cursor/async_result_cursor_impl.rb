module Neo4j::Driver
  module Internal
    module Cursor
      class AsyncResultCursorImpl
        delegate :consume_async, :next_async, :peek_async, to: :@pull_all_handler

        def initialize(run_error, run_handler, pull_all_handler)
          @run_error = run_error
          @run_handler = run_handler
          @pull_all_handler = pull_all_handler
        end

        def keys
          @run_handler.query_keys.keys
        end

        def single_async
          next_async.then_compose do |first_record|
            if first_record.nil?
              raise Exceptions::NoSuchRecordException, 'Cannot retrieve a single record, because this result is empty.'
            end

            next_async.then_apply do |second_record|
              unless second_record.nil?
                raise Exceptions::NoSuchRecordException, 'Expected a result with a single record, but this result contains at least one more. Ensure your query returns only one record.'
              end

              first_record
            end
          end
        end

        def for_each_async(action)
          result_future = java.util.concurrent.CompletableFuture.new
          internal_for_each_async(action, result_future)
          result_future.then_compose(-> (_ignore){ consume_async })
        end

        def list_async(map_function = java.util.function.Function.identity)
          @pull_all_handler.list_async(map_function)
        end

        def discard_all_failure_async
          # runError has priority over other errors and is expected to have been reported to user by now
          consume_async.handle(-> (summary, error) { @run_error.nil? ? error : nil })
        end

        def pull_all_failure_async
          # runError has priority over other errors and is expected to have been reported to user by now
          @pull_all_handler.pull_all_failure_async.then_apply(-> (error) { @run_error.nil? ? error : nil })
        end

        private def internal_for_each_async(action, result_future)
          record_future = next_async

          # use async completion listener because of recursion, otherwise it is possible for
          # the caller thread to get StackOverflowError when result is large and buffered
          record_future.when_complete_async do |record, completion_error|
            error = Util::Futures.completion_exception_cause(completion_error)

            if !error.nil?
              result_future.complete_exceptionally(error)
            elsif !record.nil?
              begin
                action.accept(record)
              rescue StandardError => action_error
                return result_future.complete_exceptionally(action_error)
              end

              internal_for_each_async(action, result_future)
            else
              result_future.complete(nil)
            end
          end
        end

        def map_successful_run_completion_async
          @run_error.nil? ? java.util.concurrent.CompletableFuture.completed_future(self) : Util::Futures.failed_future(@run_error)
        end
      end
    end
  end
end
