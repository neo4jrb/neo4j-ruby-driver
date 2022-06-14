module Neo4j::Driver
  module Internal
    module Handlers
      module Pulln
        class BasicPullResponseHandler
          include Spi::ResponseHandler
          attr :state

          def initialize(query, run_response_handler, connection, metadata_extractor, completion_listener)
            super()
            @query = Validator.require_non_nil!(query)
            @run_response_handler = Validator.require_non_nil!(run_response_handler)
            @metadata_extractor = Validator.require_non_nil!(metadata_extractor)
            @connection = Validator.require_non_nil!(connection)
            @completion_listener = Validator.require_non_nil!(completion_listener)
            @state = State::READY_STATE
            @to_request = 0
          end

          def state=(state)
            @state = state
            signal
          end

          def on_success(metadata)
            assert_record_and_summary_consumer_installed
            @state.on_success(self, metadata)
          end

          def on_failure(error)
            assert_record_and_summary_consumer_installed
            @state.on_failure(self, error)
          end

          def on_record(fields)
            assert_record_and_summary_consumer_installed
            @state.on_record(self, fields)
          end

          def request(size)
            assert_record_and_summary_consumer_installed
            @state.request(self, size)
          end

          def cancel
            assert_record_and_summary_consumer_installed
            @state.cancel(self)
          end

          def complete_with_failure(error)
            @completion_listener.after_failure(error)
            complete(extract_result_summary, error)
          end

          def complete_with_success(metadata)
            @completion_listener.after_success(metadata)
            summary, exception =
              begin
                [extract_result_summary(**metadata), nil]
              rescue Exceptions::Neo4jException => e
                [extract_result_summary, e]
              end
            complete(summary, exception)
          end

          def success_has_more
            if @to_request > 0 || @to_request == FetchSizeUtil::UNLIMITED_FETCH_SIZE
              request(@to_request)
              @to_request = 0
            end

            # summary consumer use (null, null) to identify done handling of success with has_more
            @summary_consumer.call(nil, nil)
          end

          def handle_record(fields)
            record = InternalRecord.new(@run_response_handler.query_keys, fields)
            @record_consumer.call(record, nil)
          end

          def write_pull(n)
            @connection.write_and_flush(Messaging::Request::PullMessage.new(n, @run_response_handler.query_id), self)
          end

          def discard_all
            @connection.write_and_flush(Messaging::Request::DiscardMessage.new_discard_all_message(@run_response_handler.query_id), self)
          end

          def install_summary_consumer(&summary_consumer)
            raise Exceptions::IllegalStateException, 'Summary consumer already installed.' if @summary_consumer

            @summary_consumer = summary_consumer
          end

          def install_record_consumer(&record_consumer)
            raise Exceptions::IllegalStateException, 'Record consumer already installed.' if @record_consumer

            @record_consumer = record_consumer
          end

          def done?
            @state == State::SUCEEDED_STATE || @state == State::FAILURE_STATE
          end

          private def extract_result_summary(**metadata)
            result_available_after = @run_response_handler.result_available_after
            @metadata_extractor.extract_summary(@query, @connection, result_available_after, metadata)
          end

          private def add_to_request(to_add)
            return if @to_request == FetchSizeUtil::UNLIMITED_FETCH_SIZE

            # pull all
            return @to_request = FetchSizeUtil::UNLIMITED_FETCH_SIZE if to_add == FetchSizeUtil::UNLIMITED_FETCH_SIZE

            if to_add <= 0
              raise ArgumentError, "Cannot request record amount that is less than or equal to 0. Request amount: #{to_add}"
            end

            @to_request += to_add

            # to_add is already at least 1, we hit buffer overflow
            @to_request = [@to_request, LONG_MAX_VALUE].min
          end

          private def assert_record_and_summary_consumer_installed
            # no need to check if we've finished.
            return if done?

            if @record_consumer.nil? || @summary_consumer.nil?
              raise Exceptions::IllegalStateException, "Access record stream without record consumer and/or summary consumer. Record consumer=#{@record_consumer}, Summary consumer=#{@summary_consumer}"
            end
          end

          private def complete(summary, error)
            # we first inform the summary consumer to ensure when streaming finished, summary is definitely available.
            @summary_consumer.call(summary, error)
            # record consumer use (nil, nil) to identify the end of record stream
            @record_consumer.call(nil, error)
            dispose
          end

          private def dispose
            # release the reference to the consumers who hold the reference to subscribers which shall be released when subscription is completed.
            @record_consumer = nil
            @summary_consumer = nil
          end

          module State
            READY_STATE = Class.new do
              def on_success(context, metadata)
                context.state = SUCCEEDED_STATE
                context.complete_with_success(metadata)
              end

              def on_failure(context, error)
                context.state = FAILURE_STATE
                context.complete_with_failure(error)
              end

              def on_record(context, _fields)
                context.state = READY_STATE
              end

              def request(context, n)
                context.state = STREAMING_STATE
                context.write_pull(n)
              end

              def cancel(context)
                context.state = CANCELLED_STATE
                context.discard_all
              end
            end.new

            STREAMING_STATE = Class.new do
              def on_success(context, metadata)
                if metadata[:has_more]
                  context.state = READY_STATE
                  context.success_has_more
                else
                  context.state = SUCEEDED_STATE
                  context.complete_with_success(metadata)
                end
              end

              def on_failure(context, error)
                context.state = FAILURE_STATE
                context.complete_with_failure(error)
              end

              def on_record(context, fields)
                context.state = STREAMING_STATE
                context.handle_record(fields)
              end

              def request(context, n)
                context.state = STREAMING_STATE
                context.add_to_request(n)
              end

              def cancel(context)
                context.state = CANCELLED_STATE
              end
            end.new

            CANCELLED_STATE = Class.new do
              def on_success(context, metadata)
                if metadata[:has_more]
                  context.state = CANCELLED_STATE
                  context.discard_all
                else
                  context.state = SUCEEDED_STATE
                  context.complete_with_success(metadata)
                end
              end

              def on_failure(context, error)
                context.state = FAILURE_STATE
                context.complete_with_failure(error)
              end

              def on_record(context, _fields)
                context.state = CANCELLED_STATE
              end

              def request(context, _n)
                context.state = CANCELLED_STATE
              end

              def cancel(context)
                context.state = CANCELLED_STATE
              end
            end.new

            SUCEEDED_STATE = Class.new do
              def on_success(context, metadata)
                context.state = SUCEEDED_STATE
                context.complete_with_success(metadata)
              end

              def on_failure(context, error)
                context.state = FAILURE_STATE
                context.complete_with_failure(error)
              end

              def on_record(context, _fields)
                context.state = SUCEEDED_STATE
              end

              def request(context, _n)
                context.state = SUCEEDED_STATE
              end

              def cancel(context)
                context.state = SUCEEDED_STATE
              end
            end.new

            FAILURE_STATE = Class.new do
              def on_success(context, metadata)
                context.state = SUCEEDED_STATE
                context.complete_with_success(metadata)
              end

              def on_failure(context, error)
                context.state = FAILURE_STATE
                context.complete_with_failure(error)
              end

              def on_record(context, _fields)
                context.state = FAILURE_STATE
              end

              def request(context, _n)
                context.state = FAILURE_STATE
              end

              def cancel(context)
                context.state = FAILURE_STATE
              end
            end.new
          end
        end
      end
    end
  end
end
