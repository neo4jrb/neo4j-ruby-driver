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
          next_async.then_flat do |first_record|
            if first_record.nil?
              raise Exceptions::NoSuchRecordException, 'Cannot retrieve a single record, because this result is empty.'
            end
            next_async.then do |second_record|
              if second_record
                raise Exceptions::NoSuchRecordException, 'Expected a result with a single record, but this result contains at least one more. Ensure your query returns only one record.'
              end
              first_record
            end
          end
        end

        def each_async(&action)
          result_future = Concurrent::Promises.resolvable_future
          internal_for_each_async(result_future, &action)
          result_future.then_flat { consume_async }
        end

        def to_async(&map_function)
          @pull_all_handler.list_async(&block_given? ? map_function : :itself)
        end

        def discard_all_failure_async
          # runError has priority over other errors and is expected to have been reported to user by now
          consume_async.chain { |_fulfilled, _summary, error| @run_error ? nil : error }
        end

        def pull_all_failure_async
          # runError has priority over other errors and is expected to have been reported to user by now
          @pull_all_handler.pull_all_failure_async.then { |error| @run_error ? nil : error }
        end

        private def internal_for_each_async(result_future, &action)
          record_future = next_async

          # use async completion listener because of recursion, otherwise it is possible for
          # the caller thread to get StackOverflowError when result is large and buffered
          record_future.on_complete do |_fulfilled, record, error|
            if error
              result_future.reject(error)
            elsif record
              begin
                yield record
              rescue StandardError => action_error
                result_future.reject(action_error)
                return
              end
              internal_for_each_async(result_future, &action)
            else
              result_future.fulfill(nil)
            end
          end
        end

        def map_successful_run_completion_async
          @run_error ? Util::Futures.failed_future(@run_error) : Concurrent::Promises.fulfilled_future(self)
        end
      end
    end
  end
end