module Neo4j::Driver
  module Internal
    module Cursor
      # Used by Bolt V1, V2, V3
      class AsyncResultCursorOnlyFactory
        def initialize(connection, run_message, run_handler, run_future, pull_handler)
          java.util.Objects.require_non_null(connection)
          java.util.Objects.require_non_null(run_message)
          java.util.Objects.require_non_null(run_handler)
          java.util.Objects.require_non_null(run_future)
          java.util.Objects.require_non_null(pull_handler)

          @connection = connection
          @run_message = run_message
          @run_handler = run_handler
          @run_future = run_future

          @pull_all_handler = pull_handler
        end

        def async_result
          # only write and flush messages when async result is wanted.
          @connection.write(@run_message, @run_handler) # queues the run message, will be flushed with pull message together
          @pull_all_handler.pre_populate_records

          @run_future.handle(-> (_ignored, error) { DisposableAsyncResultCursor.new(AsyncResultCursorImpl.new(error, @run_handler, @pull_all_handler)) })
        end

        def rx_result
          Util::Futures.failed_future(Exceptions::ClientException.new('Driver is connected to the database that does not support driver reactive API. In order to use the driver reactive API, please upgrade to neo4j 4.0.0 or later.'))
        end
      end
    end
  end
end
