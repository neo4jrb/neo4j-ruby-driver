module Neo4j::Driver
  module Internal
    module Cursor
      # Bolt V4
      class ResultCursorFactoryImpl
        def initialize(connection, run_message, run_handler, pull_handler, pull_all_handler)
          @connection = Internal::Validator.require_non_nil!(connection)
          @run_message = Internal::Validator.require_non_nil!(run_message)
          @run_handler = Internal::Validator.require_non_nil!(run_handler)
          @pull_handler = Internal::Validator.require_non_nil!(pull_handler)
          @pull_all_handler = Internal::Validator.require_non_nil!(pull_all_handler)
        end

        def async_result
          # only write and flush messages when async result is wanted.
          @connection.write(@run_message, @run_handler) # queues the run message, will be flushed with pull message together
          @pull_all_handler.pre_populate_records

          DisposableAsyncResultCursor.new(AsyncResultCursorImpl.new(@run_handler, @pull_all_handler))
        end
      end
    end
  end
end
