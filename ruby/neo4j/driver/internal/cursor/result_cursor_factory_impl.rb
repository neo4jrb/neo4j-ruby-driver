module Neo4j::Driver
  module Internal
    module Cursor
      # Bolt V4
      class ResultCursorFactoryImpl
        def initialize(connection, run_message, run_handler, run_future, pull_handler, pull_all_handler)
          java.util.Objects.require_non_null(connection)
          java.util.Objects.require_non_null(run_message)
          java.util.Objects.require_non_null(run_handler)
          java.util.Objects.require_non_null(run_future)
          java.util.Objects.require_non_null(pull_handler)
          java.util.Objects.require_non_null(pull_all_handler)

          @connection = connection
          @run_message = run_message
          @run_handler = run_handler
          @run_future = run_future
          @pull_handler = pull_handler
          @pull_all_handler = pull_all_handler
        end

        def async_result
          # only write and flush messages when async result is wanted.
          @connection.write(@run_message, @run_handler) # queues the run message, will be flushed with pull message together
          @pull_all_handler.pre_populate_records

          @run_future.handle(-> (_ignored, error) { DisposableAsyncResultCursor.new(AsyncResultCursorImpl.new(error, @run_handler, @pull_all_handler)) })
        end

        def rx_result
          @connection.write_and_flush(@run_message, @run_handler)
          @run_future.handle(-> (_ignored, error) { RxResultCursorImpl.new(error, @run_handler, @pull_handler) } )
        end
      end
    end
  end
end
