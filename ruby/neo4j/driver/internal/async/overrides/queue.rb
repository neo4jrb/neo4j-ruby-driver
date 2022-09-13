module Neo4j::Driver
  module Internal
    module Async
      module Overrides
        class Queue < ::Async::Queue
          # Async::Task.current call throws error if called outside of Async or Sync block
          # making this call optional to make this work with/without Async/Sync
          def signal(value = nil, task: nil)
            return if @waiting.empty? || !::Async::Task.current?

            task ||= ::Async::Task.current
            Fiber.scheduler.push Signal.new(@waiting, value)

            @waiting = []

            return nil
          end
        end
      end
    end
  end
end
