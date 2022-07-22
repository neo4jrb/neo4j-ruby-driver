module Neo4j::Driver
  module Internal
    module Cursor
      class DisposableAsyncResultCursor
        include Enumerable
        delegate :keys, :pull_all_failure_async, to: :@delegate

        def initialize(delegate)
          @delegate = delegate
        end

        def consume_async
          @disposed = true
          @delegate.consume_async
        end

        def next_async
          assert_not_disposed
          @delegate.next_async
        end

        def peek_async
          assert_not_disposed
          @delegate.peek_async
        end

        def single_async
          assert_not_disposed
          @delegate.single_async
        end

        def each(&action)
          assert_not_disposed
          @delegate.each(&action)
        end

        def discard_all_failure_async
          @disposed = true
          @delegate.discard_all_failure_async
        end

        private def assert_not_disposed
          raise Neo4j::Driver::Internal::Util.new_result_consumed_error if @disposed
        end

        def disposed?
          @disposed
        end

        def map_successful_run_completion_async
          @delegate.map_successful_run_completion_async
        end
      end
    end
  end
end
