module Neo4j::Driver
  module Internal
    module Util
      class LockUtil
        class << self
          def execute_with_lock(lock)
            lock.lock
            begin
              yield
            ensure
              lock.unlock
            end
          end

          def execute_with_lock_async(lock)
            lock.lock
            Concurrent::Promises.fulfilled_future(lock).then_flat { yield }.on_fulfillment! { lock.unlock }
          end
        end
      end
    end
  end
end
