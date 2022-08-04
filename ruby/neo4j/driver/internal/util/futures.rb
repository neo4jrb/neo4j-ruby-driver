# frozen_string_literal: true

module Neo4j::Driver
  module Internal
    module Util
      class Futures
        # TO DO: complete this class, this was partially migrated

        private

        COMPLETED_WITH_NULL = Concurrent::Promises.fulfilled_future(nil)

        public

        class << self
          def completed_with_null
            COMPLETED_WITH_NULL
          end

          def completed_with_null_if_no_error(future, error)
            error ? future.reject(error) : future.fulfill(nil)
          end

          def failed_future(error)
            Concurrent::Promises.rejected_future(error)
          end

          def blocking_get(stage)
            Async::Connection::EventLoopGroupFactory.assert_not_in_event_loop_thread

            interrupted = false
            begin
              loop do
                break stage.values
              rescue Interrupt => e
                # this thread was interrupted while waiting
                # computation denoted by the future might still be running
                interrupted = true

                # run the interrupt handler and ignore if it throws
                # need to wait for IO thread to actually finish, can't simply re-rethrow
                yield rescue nil

              rescue => e
                ErrorUtil.rethrow_async_exception(e)
                # rescue java.util.concurrent.ExecutionException => e
                #   ErrorUtil.rethrow_async_exception(e)
              end
            ensure
              Thread.current.interrupt if interrupted
            end
          end

          def get_now(stage)
            stage.resolved? ? stage.value! : nil
          end

          def join_now_or_else_throw(future)
            if future.resolved?
              future.value!
            else
              raise yield
            end
          end

          def combine_errors(error1, error2)
            ErrorUtil.add_suppressed(error1, error2) if error1 && error2
            error1 || error2
          end

          def on_error_continue(future, error_recorder)
            Validator.require_non_nil!(future)

            future
              .then { |value| CompletionResult.new(value, nil) }
              .rescue do |error|
              Futures.combine_errors(error_recorder, error)
              CompletionResult.new(nil, error)
            end.then_flat do |result|
              if result.value.nil?
                yield result.error
              else
                Concurrent::Promises.fulfilled_future(result.value)
              end
            end
          end

          def future_completing_consumer(future, fulfilled, value, throwable)
            fulfilled ? future.fulfill(value) : future.reject(throwable)
          end

          private

          CompletionResult = Struct.new(:value, :error)

          def no_op_interrupt_handler
          end
        end
      end
    end
  end
end
