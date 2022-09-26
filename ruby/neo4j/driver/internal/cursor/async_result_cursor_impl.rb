module Neo4j::Driver
  module Internal
    module Cursor
      class AsyncResultCursorImpl
        delegate :consume_async, :next_async, :peek_async, to: :@pull_all_handler

        def initialize(run_handler, pull_all_handler)
          @run_handler = run_handler
          @pull_all_handler = pull_all_handler
        end

        def keys
          @run_handler.query_keys
        end

        def single_async
          next_async.compose do |first_record|
            unless first_record
              raise Exceptions::NoSuchRecordException, 'Cannot retrieve a single record, because this result is empty.'
            end
            next_async.then do |second_record|
              if second_record
                raise Exceptions::NoSuchRecordException,
                      'Expected a result with a single record, but this result contains at least one more. Ensure your query returns only one record.'
              end
              first_record
            end
          end
        end

        def list_async(&map_function)
          @pull_all_handler.list_async(&block_given? ? map_function : :itself)
        end

        def discard_all_failure_async
          # runError has priority over other errors and is expected to have been reported to user by now
          consume_async.error.then { |error| run_error ? nil : error }
        end

        def pull_all_failure_async
          # runError has priority over other errors and is expected to have been reported to user by now
          @pull_all_handler.pull_all_failure_async.then { |error| run_error ? nil : error }
        end

        def map_successful_run_completion_async
          run_error&.then(&Util::ResultHolder.method(:failed)) || Util::ResultHolder.successful(self)
        end

        def run_error
          @run_handler.error
        end
      end
    end
  end
end
