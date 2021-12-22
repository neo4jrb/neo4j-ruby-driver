# frozen_string_literal: true

module Neo4j::Driver
  module Internal
    module Util
      class Futures
        # TO DO: complete this class, this was partially migrated
        extend Ext::AsyncConverter

        class << self
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
        end
      end
    end
  end
end
