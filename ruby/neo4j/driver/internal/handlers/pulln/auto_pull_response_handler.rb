module Neo4j::Driver
  module Internal
    module Handlers
      module Pulln
        class AutoPullResponseHandler < BasicPullResponseHandler
          UNINITIALIZED_RECORDS = ::Async::Queue.new

          def initialize(query, run_response_handler, connection, metadata_extractor, completion_listener, fetch_size)
            super(query, run_response_handler, connection, metadata_extractor, completion_listener)
            @fetch_size = fetch_size

            # For pull everything ensure conditions for disabling auto pull are never met
            if fetch_size
              @high_record_watermark = fetch_size * 0.7
              @low_record_watermark = fetch_size * 0.3
            else
              @high_record_watermark = java.lang.Math::Long::MAX_VALUE
              @low_record_watermark = java.lang.Math::Long::MAX_VALUE
            end

            @records = UNINITIALIZED_RECORDS
            @auto_pull_enabled = true

            install_record_and_summary_consumers
          end

          private def install_record_and_summary_consumers
            install_record_consumer do |record, error|
              if record
                enqueue_record(record)
                complete_record_future(record)
              end

              # if !error.nil? Handled by summary.error already
              if record.nil? && error.nil?
                # complete
                complete_record_future(nil)
              end
            end

            install_summary_consumer do |summary, error|
              unless error.nil?
                handle_failure(error)
              end

              unless summary.nil?
                @summary = summary
                complete_summary_future(summary)
              end

              if error.nil? && summary.nil? # has_more
                request(@fetch_size) if @auto_pull_enabled
              end
            end
          end

          private def handle_failure(error)
            # error has not been propagated to the user, remember it
            unless fail_record_future(error) && fail_summary_future(error)
              @failure = error
            end
          end

          def peek_async
            while @records.empty? && !done?
              wait
            end
            @records.items.first
          end

          def next_async
            dequeue_record if peek_async
          end

          def consume_async
            @records.items.clear
            return completed_with_value_if_no_failure(@summary) if done?
            cancel
            @summary
          end

          def list_async(map_function)
            pull_all_async.then_apply(-> (summary) { records_as_list(map_function) })
          end

          def pull_all_failure_async
            pull_all_async
          end

          def pre_populate_records
            request(@fetch_size)
          end

          private

          def pull_all_async
            return completed_with_value_if_no_failure(@summary) if done?

            request(nil)

            @summary_future = java.util.concurrent.CompletableFuture.new if @summary_future.nil?

            @summary_future
          end

          def enqueue_record(record)
            @records << record

            # too many records in the queue, pause auto request gathering
            @auto_pull_enabled = false if @records.size > @high_record_watermark
          end

          def dequeue_record
            record = @records.dequeue

            if @records.size <= @low_record_watermark
              # if not in streaming state we need to restart streaming
              request(@fetch_size) if state == !State::STREAMING_STATE

              @auto_pull_enabled = true
            end

            record
          end

          def records_as_list(map_function)
            if done?
              raise Exceptions::IllegalStateException, "Can't get records as list because SUCCESS or FAILURE did not arrive"
            end

            result = []

            @records.each do |record|
              result << map_function.apply(record)
            end

            @records.clear
            result
          end

          def extract_failure
            raise Exceptions::IllegalStateException, "Can't extract failure because it does not exist" unless @failure
            error = @failure
            @failure = nil # propagate failure only once
            error
          end

          def complete_record_future(record)
            unless @record_future.nil?
              future = @record_future
              @record_future = nil
              future.complete(record)
            end
          end

          def complete_summary_future(summary)
            unless @summary_future.nil?
              future = @summary_future
              @summary_future = nil
              future.complete(summary)
            end
          end

          def fail_record_future(error)
            unless @record_future.nil?
              future = @record_future
              @record_future = nil
              future.complete(record)
              return true
            end

            false
          end

          def completed_with_value_if_no_failure(value)
            @failure ? extract_failure : value
          end
        end
      end
    end
  end
end
