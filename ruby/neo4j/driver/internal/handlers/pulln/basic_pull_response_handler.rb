module Neo4j::Driver
  module Internal
    module Handlers
      module Pulln
        class BasicPullResponseHandler
          attr_accessor :state

          def initialize(query, run_response_handler, connection, metadata_extractor, completion_listener)
            @query = java.util.Objects.require_non_null(query)
            @run_response_handler = java.util.Objects.require_non_null(run_response_handler)
            @metadata_extractor = java.util.Objects.require_non_null(metadata_extractor)
            @connection = java.util.Objects.require_non_null(connection)
            @completion_listener = java.util.Objects.require_non_null(completion_listener)
            @state = State::ReadyState
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
            complete(extract_result_summary({}), error)
          end

          def complete_with_success(metadata)
            @completion_listener.after_failure(metadata)
            summary = extract_result_summary(metadata)
            complete(summary, nil)
          end

          def success_has_more
            if @to_request.nil? || @to_request > 0
              request(@to_request)
              @to_request = 0
            end

            # summary consumer use (null, null) to identify done handling of success with has_more
            @summary_consumer.accept(nil, nil)
          end

          def handle_record(fields)
            record = InternalRecord.new(@run_response_handler.query_keys, fields)
            @record_consumer.accept(record, nil)
          end

          def write_pull(n)
            @connection.write_and_flush(Messaging::PullMessage.new(n, @run_response_handler.query_id), self)
          end

          def discard_all
            connection.writeAndFlush(Messaging::Request::DiscardMessage.new_discard_all_message(@run_response_handler.query_id), self)
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
            @state.eql?(State::SucceededState) || @state.eql?(State::FailureState)
          end

          private def extract_result_summary(metadata)
            result_available_after = @run_response_handler.result_available_after
            @metadata_extractor.extract_summary(@query, connection, result_available_after, metadata)
          end

          private def add_to_request(to_add)
            return unless @to_request

            # pull all
            return @to_request = nil unless to_add

            if to_add <= 0
              raise java.lang.IllegalArgumentException, "Cannot request record amount that is less than or equal to 0. Request amount: #{to_add}"
            end

            @to_request += to_add

            # to_add is already at least 1, we hit buffer overflow
            @to_request = java.lang.Long::MAX_VALUE if @to_request <= 0
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
            @summary_consumer.accept(summary, error)

            # record consumer use (nil, nil) to identify the end of record stream
            @record_consumer.accept(nil, error)
            dispose
          end

          private def dispose
            # release the reference to the consumers who hold the reference to subscribers which shall be released when subscription is completed.
            @record_consumer, @summary_consumer = nil
          end

          module State
            module ReadyState
              def self.on_success(context, metadata)
                context.state(SucceededState)
                context.complete_with_success(metadata)
              end

              def self.on_failure(context, error)
                context.state(FailureState)
                context.complete_with_failure(error)
              end

              def self.on_record(context, _fields)
                context.state(ReadyState)
              end

              def self.request(context, n)
                context.state(StreamingState)
                context.write_pull(n)
              end

              def self.cancel(context)
                context.state(CancelledState)
                context.discard_all
              end
            end

            module StreamingState
              def self.on_success(context, metadata)
                if metadata(:has_more)
                  context.state(ReadyState)
                  context.success_has_more
                else
                  context.state(SucceededState)
                  context.complete_with_success(metadata)
                end
              end

              def self.on_failure(context, error)
                context.state(FailureState)
                context.complete_with_failure(error)
              end

              def self.on_record(context, fields)
                context.state(StreamingState)
                context.handle_record(fields)
              end

              def self.request(context, n)
                context.state(StreamingState)
                context.add_to_request(n)
              end

              def self.cancel(context)
                context.state(CancelledState)
              end
            end

            module CancelledState
              def self.on_success(context, metadata)
                if metadata(:has_more)
                  context.state(CancelledState)
                  context.discard_all
                else
                  context.state(SucceededState)
                  context.complete_with_success(metadata)
                end
              end

              def self.on_failure(context, error)
                context.state(FailureState)
                context.complete_with_failure(error)
              end

              def self.on_record(context, _fields)
                context.state(CancelledState)
              end

              def self.request(context, _n)
                context.state(CancelledState)
              end

              def self.cancel(context)
                context.state(CancelledState)
              end
            end

            module SucceededState
              def self.on_success(context, metadata)
                context.state(SucceededState)
                context.complete_with_success(metadata)
              end

              def self.on_failure(context, error)
                context.state(FailureState)
                context.complete_with_failure(error)
              end

              def self.on_record(context, _fields)
                context.state(SucceededState)
              end

              def self.request(context, _n)
                context.state(SucceededState)
              end

              def self.cancel(context)
                context.state(SucceededState)
              end
            end

            module FailureState
              def self.on_success(context, metadata)
                context.state(SucceededState)
                context.complete_with_success(metadata)
              end

              def self.on_failure(context, error)
                context.state(FailureState)
                context.complete_with_failure(error)
              end

              def self.on_record(context, _fields)
                context.state(FailureState)
              end

              def self.request(context, _n)
                context.state(FailureState)
              end

              def self.cancel(context)
                context.state(FailureState)
              end
            end
          end
        end
      end
    end
  end
end
