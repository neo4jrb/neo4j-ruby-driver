module Neo4j::Driver
  module Internal
    module Util
      class LockUtil
        class << self
          def execute_with_lock(lock, runnable)
            lock.lock

            begin
              runnable.run
            rescue Exception => e
              lock.unlock
            end
          end

          def execute_with_lock_async(lock, stage_supplier)
            lock.lock

            java.util.concurrent.CompletableFuture.completed_future(lock).then_compose { stage_supplier }.when_complete{ lock.unlock }
          end
        end
      end
    end
  end
end
