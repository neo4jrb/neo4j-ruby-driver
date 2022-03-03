module Neo4j::Driver
  module Internal
    module Async
      class ResultCursorsHolder
        def initialize
          @cursor_stages = []
        end

        def add(cursor_stage)
          java.util.Objects.require_non_null(cursor_stage)
          @cursor_stages << cursor_stage
        end

        private

        def retrieve_not_consumed_error
          failures = retrieve_all_failures

          java.util.concurrent.CompletableFuture.all_of(failures).then_apply(-> (_ignore) { find_first_failure(failures) })
        end

        def retrieve_all_failures
          @cursor_stages.map(ResultCursorsHolder::retrieve_failure).map(java.util.concurrent.CompletionStage::to_completable_future).to_array(java.util.concurrent.CompletableFuture[]::new)
        end

        class << self
          def find_first_failure(completed_failure_futures)
            # all given futures should be completed, it is thus safe to get their values
            completed_failure_futures.each do |failure_future|
              failure = failure_future.get_now(nil) #does not block
              return failure unless failure.nil?
            end
            nil
          end

          def retrieve_failure(cursor_stage)
            cursor_stage.exceptionally(-> (cursor) { nil }).then_compose(-> (cursor) { cursor == nil ? Util::Futures.completed_with_null : cursor.discard_all_failure_async })
          end
        end
      end
    end
  end
end
