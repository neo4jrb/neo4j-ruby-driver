# frozen_string_literal: true

module Neo4j::Driver
  module Internal
    module Util
      class Futures
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
                yield rescue nil
              rescue java.util.concurrent.ExecutionException => e
                org.neo4j.driver.internal.util.ErrorUtil.rethrowAsyncException(e);
              end
            ensure
              java.lang.Thread.currentThread.interrupt if interrupted
            end
          end
        end
      end
    end
  end
end
