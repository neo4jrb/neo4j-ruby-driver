# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # The driver's IO engine. Every connection runs its reads and writes as
      # fibers on an Async reactor, so the two directions are fully independent
      # — the foundation for HELLO+LOGON pipelining, recv-timeout liveness and
      # pipelined RESET (see docs/pipelined-connection.md).
      #
      # The reactor is **latched to one home at first use**, then every
      # subsequent operation routes to that same home through a submission
      # queue drained by a single *pump* fiber:
      #
      #   * **Ambient** — if the first use happens inside an Async reactor
      #     (Falcon, or any `Async {}`), the pump is a `transient` task on
      #     *that* reactor. No extra thread; the IO fibers share the host
      #     reactor, so an operation is "async for free". Transient means a
      #     one-shot `Async {}` still returns promptly.
      #
      #   * **Owned** — otherwise (sync scripts, Puma threads) the pump runs an
      #     `Async {}` on a dedicated background thread, started lazily.
      #
      # Why latch + a single pump rather than choosing per call: a connection's
      # reader/writer fibers are long-lived, and **fibers can't cross threads**
      # (FiberError). If `run` picked the home per-call, fibers could *start* on
      # an ambient reactor but their teardown (`Connection#close`/`teardown_io`,
      # often invoked from a different thread — pool discard, driver shutdown)
      # would run on the owned thread → cross-thread fiber stop / unsafe socket
      # close. Routing *all* work — start AND teardown — through one queue to the
      # latched pump guarantees every IO op for a connection executes on the one
      # thread that owns its fibers, no matter which thread calls in. The single
      # reactor thread also serialises each socket's read+write cooperatively,
      # which is TLS-safe (never a concurrent SSL_read/SSL_write on one socket).
      #
      # Ambient-path caveat: it assumes the driver lives on a single, long-lived
      # reactor (the Falcon-per-process norm). Submissions are serviced only
      # while that reactor runs; if it has stopped (app shutdown), a later `run`
      # would wait on a pump that never wakes. Sharing one driver across several
      # independent reactors on different threads is out of scope — use the
      # owned reactor (don't first-use the driver from an ephemeral `Async {}`
      # on a worker thread).
      class Reactor
        def initialize
          @mutex = Mutex.new
          @started = false
          @thread = nil          # set only in owned mode
          @submissions = nil
          @spawn_transient = nil # children transient? (true in ambient mode)
        end

        # Submit `block` to the latched reactor, spawn it there as a fiber, and
        # return its Async::Task. Used to start a connection's reader / writer.
        # Safe from any thread: the submission queue is the cross-thread bridge.
        def run(&block)
          ensure_started
          reply = Thread::Queue.new
          @submissions.push([block, reply])
          reply.pop # the spawned Async::Task, handed back from the pump
        end

        # Submit `block`, block the caller until it returns, and propagate its
        # value or exception. Used for teardown (stop the reader/writer and
        # close the socket on the thread that owns them). The mailbox is
        # scheduler-aware, so a caller that is itself a fiber on the latched
        # reactor yields rather than blocks.
        def run_and_wait(&block)
          done = Thread::Queue.new
          run do
            done.push([:ok, block.call])
          rescue Exception => e # rubocop:disable Lint/RescueException
            done.push([:error, e])
          end
          status, value = done.pop
          raise value if status == :error

          value
        end

        # Stop the pump (and its connection fibers). Joins the owned thread; in
        # ambient mode the transient pump just ends — the host reactor is not
        # ours to stop.
        def stop
          thread = nil
          @mutex.synchronize do
            return unless @started

            @submissions.push(:stop)
            thread = @thread
            @thread = nil
            @started = false
          end
          thread&.join
        end

        private

        # Latch the reactor home on first use. Ambient: host the pump on the
        # caller's reactor as a transient task. Owned: spin a background thread
        # whose `Async {}` runs the pump. Either way the pump drains
        # @submissions; from here `run` is home-agnostic.
        def ensure_started
          @mutex.synchronize do
            return if @started

            @started = true
            @submissions = Thread::Queue.new
            if (task = Async::Task.current?)
              @spawn_transient = true
              task.reactor.async(transient: true) { pump }
            else
              @spawn_transient = false
              ready = Thread::Queue.new
              @thread = Thread.new { Async { ready.push(true); pump } }
              ready.pop
            end
          end
        end

        # Drain submissions and spawn each as a child of the pump task, handing
        # the spawned task back via its reply queue. `@submissions.pop` is
        # scheduler-aware: it yields the reactor while idle and wakes on a
        # cross-thread push. On :stop, stop any still-running connection fibers.
        # Children are transient in ambient mode so they never keep a one-shot
        # host `Async {}` open.
        def pump
          parent = Async::Task.current
          loop do
            item = @submissions.pop
            break if item == :stop

            block, reply = item
            reply.push(parent.async(transient: @spawn_transient, &block))
          end
          # Async::List#each is safe against the removal each stop triggers
          # (mirrors Async's own Node#stop_children); never dup the list — it's
          # an intrusive linked list and copying it corrupts the nodes.
          parent.children&.each(&:stop)
        end
      end
    end
  end
end
