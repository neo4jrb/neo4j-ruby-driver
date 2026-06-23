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
        #
        # CRuby only: JRuby's Fiber-scheduler support is incomplete (no IO_Event
        # selector; the scheduler's I/O hooks don't fire), so even when a host
        # installs one we must not hand the pump to it — `Fiber.schedule` there
        # fails / desyncs the stream. The mri-on-jruby flavor is thread-only by
        # design (same reason lib/mri can't run on the async reactor under JRuby),
        # so on JRuby we always spawn a real thread regardless of any scheduler.
        def reactor? = RUBY_PLATFORM != 'java' && !Fiber.scheduler.nil?

        # Run `block` in the background-appropriate context and return a handle
        # responding to #alive? / #join. Without a scheduler the pump gets its own
        # thread — a plain Thread already satisfies that interface, so it's
        # returned as-is. Under a scheduler it's a fiber, wrapped (see below).
        def spawn(&block)
          reactor? ? FiberHandle.new(Fiber.schedule(&block)) : Thread.new(&block)
        end

        # Adapter for the reactor path only: a scheduled fiber doesn't satisfy the
        # thread-shaped handle interface — there's no Fiber#join (it's driven by
        # the host reactor; the consumer observes completion via the buffer's
        # stream-end signal, not by joining), and #alive? maps straight through.
        FiberHandle = Struct.new(:fiber) do
          def alive? = fiber.alive?
          def join = nil
        end
      end
    end
  end
end
