module Neo4j::Driver
  module Internal
    module Async
      class ResultCursorsHolder < Array
        def retrieve_not_consumed_error
          retrieve_all_failures.find { |failure| failure }
        end

        private

        def retrieve_all_failures
          map(&:discard_all_failure_async)
        end
      end
    end
  end
end
