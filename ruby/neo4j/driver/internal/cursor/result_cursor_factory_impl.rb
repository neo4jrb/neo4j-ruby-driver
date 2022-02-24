module Neo4j::Driver
  module Internal
    module Cursor
      # Bolt V4
      class ResultCursorFactoryImpl
        def initialize(connection, run_message, run_handler, run_future, pull_handler, pull_all_handler)
          @connection = Internal::Validator.require_non_nil!(connection)
          @run_message = Internal::Validator.require_non_nil!(run_message)
          @run_handler = Internal::Validator.require_non_nil!(run_handler)
          @run_future = Internal::Validator.require_non_nil!(run_future)
          @pull_handler = Internal::Validator.require_non_nil!(pull_handler)
          @pull_all_handler = Internal::Validator.require_non_nil!(pull_all_handler)
        end

        def async_result
          # only write and flush messages when async result is wanted.
          @connection.write(@run_message, @run_handler) # queues the run message, will be flushed with pull message together
          @pull_all_handler.pre_populate_records

          @run_future.handle do |_ignored, error|
            DisposableAsyncResultCursor.new(AsyncResultCursorImpl.new(error, @run_handler, @pull_all_handler))
          end
        end

        def rx_result
          @connection.write_and_flush(@run_message, @run_handler)
          @run_future.handle { |_ignored, error| RxResultCursorImpl.new(error, @run_handler, @pull_handler) }
        end
      end
    end
  end
end
