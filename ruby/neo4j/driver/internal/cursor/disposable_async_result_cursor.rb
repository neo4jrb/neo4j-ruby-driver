module Neo4j::Driver
  module Internal
    module Cursor
      class DisposableAsyncResultCursor
        attr_accessor :disposed

        delegate :keys, :pull_all_failure_async, to: :@delegate

        def initialize(delegate)
          @delegate = delegate
        end

        def consume_async
          disposed = true
          @delegate.consume_async
        end

        def next_async
          assert_not_disposed.then_compose(-> (_ignored) { @delegate.next_async })
        end

        def peek_async
          assert_not_disposed.then_compose(-> (_ignored) { @delegate.peek_async })
        end

        def single_async
          assert_not_disposed.then_compose(-> (_ignored) { @delegate.single_async })
        end

        def for_each_async(action)
          assert_not_disposed.then_compose(-> (_ignored) { @delegate.for_each_async(action) })
        end

        def list_async(map_function = nil)
          return assert_not_disposed.then_compose(-> (_ignored) { @delegate.list_async(map_function) }) if map_function.present?

          assert_not_disposed.then_compose(-> (_ignored) { @delegate.list_async })
        end

        def discard_all_failure_async
          disposed = true
          @delegate.discard_all_failure_async
        end

        private def assert_not_disposed
          return Util::Futures.failed_future(new_result_consumed_error) if disposed

          Util::Futures.completed_with_null
        end

        def map_successful_run_completion_async
          @delegate.map_successful_run_completion_async
        end
      end
    end
  end
end
