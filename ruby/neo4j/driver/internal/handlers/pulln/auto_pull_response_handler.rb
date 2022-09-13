module Neo4j::Driver
  module Internal
    module Handlers
      module Pulln
        class AutoPullResponseHandler < BasicPullResponseHandler
          include Enumerable
          delegate :signal, to: :@records
          LONG_MAX_VALUE = 2 ** 63 - 1

          def initialize(query, run_response_handler, connection, metadata_extractor, completion_listener, fetch_size)
            super(query, run_response_handler, connection, metadata_extractor, completion_listener)
            @fetch_size = fetch_size

            # For pull everything ensure conditions for disabling auto pull are never met
            if fetch_size == FetchSizeUtil::UNLIMITED_FETCH_SIZE
              @high_record_watermark = LONG_MAX_VALUE
              @low_record_watermark = LONG_MAX_VALUE
            else
              @high_record_watermark = fetch_size * 0.7
              @low_record_watermark = fetch_size * 0.3
            end

            @records = Async::Overrides::Queue.new
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
              handle_failure(error) if error

              if summary
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
            unless fail_record_future(error) || fail_summary_future(error)
              @failure = error
            end
          end

          def peek_async
            while @records.empty? && !done?
              @records.wait
            end
            @records.items.first&.then(&Util::ResultHolder.method(:successful)) or
              completed_with_value_if_no_failure(nil)
          end

          def next_async
            peek_async.then { |record| dequeue_record if record }
          end

          def consume_async
            @records.items.clear
            cancel unless done?
            completed_with_value_if_no_failure(@summary)
          end

          def each
            pull_all_async.then do
              unless done?
                raise Exceptions::IllegalStateException, "Can't get records as list because SUCCESS or FAILURE did not arrive"
              end
              @records.each { |record| yield record }
            end
          end

          def pull_all_failure_async
            pull_all_async.chain { |_, error| error }
          end

          def pre_populate_records
            request(@fetch_size)
          end

          private

          def pull_all_async
            return completed_with_value_if_no_failure(@summary) if done?
            request(FetchSizeUtil::UNLIMITED_FETCH_SIZE)
            @summary_future ||= Util::ResultHolder.new
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
              request(@fetch_size) if state != State::STREAMING_STATE

              @auto_pull_enabled = true
            end

            record
          end

          def extract_failure
            @failure or raise Exceptions::IllegalStateException, "Can't extract failure because it does not exist"
          ensure
            @failure = nil # propagate failure only once
          end

          def complete_record_future(record)
            @record_future&.succeed(record)
            @record_future = nil
          end

          def complete_summary_future(summary)
            @summary_future&.succeed(summary)
            @summary_future = nil
          end

          def fail_record_future(error)
            @record_future&.fail(error)
          ensure
            @record_future = nil
          end

          def fail_summary_future(error)
            @summary_future&.fail(error)
          ensure
            @summary_future = nil
          end

          def completed_with_value_if_no_failure(value)
            if @failure
              Util::ResultHolder.failed(extract_failure)
            else
              Util::ResultHolder.successful(value)
            end
          end
        end
      end
    end
  end
end
