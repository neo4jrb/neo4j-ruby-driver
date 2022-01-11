# frozen_string_literal: true

module Neo4j::Driver
  module Internal
    module Util
      class Futures
        # TO DO: complete this class, this was partially migrated
        extend Ext::AsyncConverter
        COMPLETED_WITH_NULL = java.util.concurrent.CompletableFuture.completed_future(nil)

        class << self
          def complete_with_null_if_no_error(future, error)
            if error.nil?
              future.complete(nil)
            else
              future.complete_exceptionally(error)
            end

            future
          end

          def as_completion_stage(future, result = java.util.concurrent.CompletableFuture.new)
            if future.cancelled?
              result.cancel(true)
            elsif future.success?
              result.complete(future.now)
            elsif !future.cause.nil?
              result.complete_exceptionally(future.cause)
            else
              future.add_listener do
                if future.cancelled?
                  result.cancel(true)
                elsif future.success?
                  result.complete(future.now)
                else
                  result.complete_exceptionally(future.cause)
                end
              end
            end

            result
          end

          def failed_future(error)
            result = java.util.concurrent.CompletableFuture.new
            result.complete_exceptionally(error)
            result
          end

          def blocking_get(stage)
            org.neo4j.driver.internal.async.connection.EventLoopGroupFactory.assertNotInEventLoopThread

            future =  stage.is_a?(Concurrent::Promises::Future) ? stage : to_future(stage)
            interrupted = false
            begin
              loop do
                return future.value!
              rescue java.lang.InterruptedException => e
                # this thread was interrupted while waiting
                # computation denoted by the future might still be running
                interrupted = true

                # run the interrupt handler and ignore if it throws
                # need to wait for IO thread to actually finish, can't simply re-rethrow
                yield if block_given? rescue nil
              rescue java.util.concurrent.ExecutionException => e
                org.neo4j.driver.internal.util.ErrorUtil.rethrowAsyncException(e);
              end
            ensure
              java.lang.Thread.currentThread.interrupt if interrupted
            end
          end

          def now(stage)
            stage.to_completable_future.now(nil)
          end

          def join_now_or_else_throw(future, exception_supplier)
            return future.join if future.done?

            raise exception_supplier
          end

          # TODO: probably not necessary with concurrent-ruby as it might not wrap exceptions like java
          def completion_exception_cause(error)
            error.is_a?(java.util.concurrent.CompletionException) ? error.get_cause : error
          end

          def combine_errors(error1, error2)
            return unless error1 && error2

            return as_completion_exception(error1) if error2.nil?

            return as_completion_exception(error2) if error1.nil?

            cause1 = completion_exception_cause(error1)
            cause2 = completion_exception_cause(error2)
            ErrorUtil.add_suppressed(cause1, cause2)
            as_completion_exception(cause1)
          end

          def as_completion_exception(error)
            error if error.instance_of?(CompletionException)

            java.util.concurrent.CompletionException.new(error)
          end

          def on_error_continue(future, error_recorder, on_error_action)
            java.util.Objects.require_non_null(future)

            future.handle do |value, error|
              unless error.nil?
                # record error
                Futures.combine_errors(errorRecorder, error)
                CompletionResult.new(nil, error)
              end

              CompletionResult.new(value, nil)
            end.then_compose do |result|
                  if result.value.nil?
                    on_error_action.apply(result.error)
                  else
                    java.util.concurrent.CompletableFuture.completed_future(result.value)
                  end
                end
          end

          def future_completing_consumer(future)
            -> (value, throwable) { throwable.nil? ? future.complete(value) : future.complete_exceptionally(throwable) }
          end

          private

          class CompletionResult
            def initialize(value, error)
              @value = value
              @error = error
            end
          end

          def safe_run(runnable)
            begin
              runnable.run
            rescue StandardError => e

            end
          end

          def no_op_interrupt_handler
          end
        end
      end
    end
  end
end
