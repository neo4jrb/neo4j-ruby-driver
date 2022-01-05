module Neo4j::Driver
  module Internal
    module Cursor
      class RxResultCursorImpl
        DISCARD_RECORD_CONSUMER = -> (record, throwable) {}

        delegate :cancel, to: :@pull_handler
        delegate :done?, to: :@summary_future

        def initialize(run_error, run_handler, pull_handler)
          java.util.Objects.require_non_null(run_handler)
          java.util.Objects.require_non_null(pull_handler)

          @run_response_error = run_error
          @run_handler = @run_handler
          @pull_handler = @pull_handler
          @summary_future = java.util.concurrent.CompletableFuture.new
          @consumer_status = NOT_INSTALLED
          install_summary_consumer
        end

        def keys
          @run_handler.query_keys.keys
        end

        def install_record_consumer(record_consumer)
          raise Util::ErrorUtil.new_result_consumed_error if result_consumed

          return if @consumer_status.installed?

          @consumer_status = record_consumer == DISCARD_RECORD_CONSUMER ? DISCARD_INSTALLED : INSTALLED
          @pull_handler.install_record_consumer(record_consumer)
          assert_run_completed_successfully
        end

        def request(n)
          n = -1 if n == java.lang.Long::MAX_VALUE

          @pull_handler.request(n)
        end

        def discard_all_failure_async
          # calling this method will enforce discarding record stream and finish running cypher query
          summary_stage.then_apply(-> (_summary) { nil }).exceptionally do |throwable|
            @summary_future_exposed ? null : throwable
          end
        end

        def pull_all_failure_async
          if @consumer_status.installed? && !done?
            return java.util.concurrent.CompletableFuture.completed_future(Exceptions::TransactionNestingException.new("You cannot run another query or begin a new transaction in the same session before you've fully consumed the previous run result."))
          end

          # It is safe to discard records as either the streaming has not started at all, or the streaming is fully finished.
          discard_all_failure_async
        end

        def summary_async
          @summary_future_exposed = true
          summary_stage
        end

        def summary_stage
          unless done? && @result_consumed # the summary is called before record streaming
            install_record_consumer(DISCARD_RECORD_CONSUMER)
            cancel
            @result_consumed = true
          end

          @summary_future
        end

        private

        def assert_run_completed_successfully
          unless @run_response_error.nil?
            @pull_handler.on_failure(@run_response_error)
          end
        end

        def install_summary_consumer
          @pull_handler.install_summary_consumer do |summary, error|
            if !error.nil? && @consumer_status.discard_consumer?
              # We will only report the error to summary if there is no user record consumer installed
              # When a user record consumer is installed, the error will be reported to record consumer instead.
              @summary_future.complete_exceptionally(error)
            elsif !summary.nil?
              @summary_future.complete(summary)
            end

            # else (nil, nil) to indicate a has_more success
          end
        end

        class RecordConsumerStatus
          NOT_INSTALLED = new(false, false)
          INSTALLED = new(true, false)
          DISCARD_INSTALLED = new(true, true)

          attr_reader :installed, :discard_consumer

          def initialize(installed, discard_consumer)
            @installed = installed
            @discard_consumer = discard_consumer
          end
        end
      end
    end
  end
end
