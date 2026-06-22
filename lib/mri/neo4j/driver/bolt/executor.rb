# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Where a background pump runs. The *only* concurrency-mode-aware seam in
      # the driver: a fiber on the host's Fiber scheduler when one is installed
      # (Falcon, or any `Async {}`), else a plain OS thread.
      #
      # Programs against Ruby's **core** Fiber-scheduler interface — `Fiber.schedule`
      # / `Fiber.scheduler` — never the `async` gem. `async` is merely one
      # implementation of that interface; the driver is a scheduler *consumer*,
      # never a provider, and falls back to threads when no scheduler is set.
      #
      # The pump body is identical in both modes — its blocking socket reads
      # auto-yield under a scheduler (colorless I/O) and block a real thread
      # without one. Cancellation is cooperative (a stop signal the pump checks),
      # so no executor-specific kill is needed.
      module Executor
        module_function

        # True when a Fiber scheduler is installed on the current thread, so a
        # spawned pump will be a fiber that cooperates with the host reactor.
        def reactor? = !Fiber.scheduler.nil?

        # Run `block` in the background-appropriate context and return a handle
        # (responds to #alive?; #join on the thread path). Under a scheduler the
        # caller and the pump share one thread cooperatively; without one the
        # pump gets its own thread.
        def spawn(&block)
          reactor? ? FiberHandle.new(Fiber.schedule(&block)) : ThreadHandle.new(Thread.new(&block))
        end

        # Thin uniform wrappers so callers don't branch on the handle type.
        ThreadHandle = Struct.new(:thread) do
          def alive? = thread.alive?
          def join = thread.join
        end

        FiberHandle = Struct.new(:fiber) do
          def alive? = fiber.alive?
          # A scheduled fiber is driven by the host reactor, not joined by a
          # caller; the consumer observes completion via the buffer's stream-end
          # signal instead. No-op so the interface stays uniform.
          def join = nil
        end
      end
    end
  end
end
