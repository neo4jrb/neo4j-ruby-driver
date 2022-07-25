module Neo4j::Driver
  module Internal
    module Cursor
      class AsyncResultCursorImpl
        include Enumerable
        delegate :consume_async, :next_async, :peek_async, to: :@pull_all_handler

        def initialize(run_handler, pull_all_handler)
          @run_handler = run_handler
          @pull_all_handler = pull_all_handler
        end

        def keys
          @run_handler.query_keys
        end

        def single_async
          first_record = next_async
          unless first_record
            raise Exceptions::NoSuchRecordException, 'Cannot retrieve a single record, because this result is empty.'
          end
          if next_async
            raise Exceptions::NoSuchRecordException,
                  'Expected a result with a single record, but this result contains at least one more. Ensure your query returns only one record.'
          end
          first_record
        end

        def each(&action)
          internal_for_each_async(&action)
          consume_async
        end

        def to_async(&map_function)
          @pull_all_handler.list_async(&block_given? ? map_function : :itself)
        end

        def discard_all_failure_async
          # runError has priority over other errors and is expected to have been reported to user by now
          consume_async #.chain { |_fulfilled, _summary, error| @run_error ? nil : error }
          nil
        end

        def pull_all_failure_async
          # runError has priority over other errors and is expected to have been reported to user by now
          @pull_all_handler.pull_all_failure_async.then { |error| run_error ? nil : error }
        end

        private def internal_for_each_async
          while record = next_async
            begin
              yield record
            rescue
              nil
            end
          end
        end

        def map_successful_run_completion_async
          run_error || self
        end

        def run_error
          @run_handler.error
        end
      end
    end
  end
end
