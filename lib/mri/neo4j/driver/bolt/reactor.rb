# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # The driver's IO engine. Every connection runs its reads and writes as
      # fibers on an Async reactor, so the two directions are fully independent
      # — the foundation for HELLO+LOGON pipelining, recv-timeout liveness and
      # pipelined RESET (see docs/pipelined-connection.md).
      #
      # A connection's fibers get one of two homes, decided per `run` from the
      # caller's context:
      #
      #   * **Ambient** — when the caller is already inside an Async reactor
      #     (Falcon, or any `Async {}` block), the fibers run on *that* reactor
      #     as `transient` tasks. No extra thread is spawned; the calling fiber
      #     and the IO fibers share one reactor, so an operation is "async for
      #     free" with no cross-thread hop. Transient tasks never keep the
      #     reactor open, so a one-shot `Async { … }` still returns promptly and
      #     they are torn down with the reactor.
      #
      #   * **Owned** — otherwise (sync scripts, Puma threads) the driver runs
      #     its own dedicated reactor on a background thread, started lazily on
      #     first use. Callers block on a scheduler-aware mailbox that the
      #     reactor completes cross-thread.
      #
      # Why a *driver-owned* (not per-caller) reactor: a connection's reader
      # fiber is long-lived — it drains responses for the connection's whole
      # life, including while the connection sits idle in the pool — and fibers
      # cannot cross threads (FiberError). Pooled connections are borrowed by
      # sessions on different threads, so the reader needs one stable home. The
      # single reactor thread also serialises each socket's read+write
      # cooperatively, which is TLS-safe (never a concurrent SSL_read/SSL_write
      # on one SSLSocket).
      #
      # Ambient-path caveat: it assumes the driver is confined to a single,
      # long-lived reactor (the Falcon-per-process norm). A connection whose
      # fibers started on one reactor thread cannot be driven from another, so
      # sharing one driver across several independent reactors on different
      # threads must use the owned reactor — i.e. don't first-use such a driver
      # from inside an ephemeral `Async {}` on a worker thread.
      class Reactor
        def initialize
          @mutex = Mutex.new
          @thread = nil
          @submissions = nil
        end

        # Run `block` as a fiber on the reactor and return its Async::Task.
        # Used to start a connection's reader / writer. When the caller is
        # already inside an Async reactor the fiber is a transient task on that
        # reactor; otherwise it runs on the driver's own background reactor.
        def run(&block)
          if (task = Async::Task.current?)
            task.reactor.async(transient: true, &block)
          else
            owned_run(&block)
          end
        end

        # Run `block` on the reactor and block the caller until it returns,
        # propagating its value or exception. Used for teardown (stop the
        # reader/writer and close the socket on the thread that owns them).
        # The mailbox is scheduler-aware, so this also works when the caller is
        # itself a fiber on the ambient reactor (it yields rather than blocks).
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

        # Tear down the owned reactor thread, if one was started. The ambient
        # reactor is not ours to stop — its transient tasks end with it (or
        # earlier, when their connection closes them).
        def stop
          thread = nil
          @mutex.synchronize do
            return unless @thread

            @submissions.push(:stop)
            thread = @thread
            @thread = nil
          end
          thread.join
        end

        private

        def owned_run(&block)
          ensure_started
          reply = Thread::Queue.new
          @submissions.push([block, reply])
          reply.pop # the spawned Async::Task, handed back from the reactor thread
        end

        def ensure_started
          @mutex.synchronize do
            return if @thread

            @submissions = Thread::Queue.new
            ready = Thread::Queue.new
            @thread = Thread.new { event_loop(ready) }
            ready.pop
          end
        end

        # The owned reactor's body: a bootstrap fiber that drains submissions
        # (pushed cross-thread by callers) and spawns each as a child task.
        # `@submissions.pop` is scheduler-aware, so it yields the reactor to the
        # connection fibers while idle and wakes on a cross-thread push.
        def event_loop(ready)
          Async do |root|
            ready.push(true)
            loop do
              item = @submissions.pop
              break if item == :stop

              block, reply = item
              reply.push(root.async(&block))
            end
            # Stop any still-running connection fibers. Async::List#each is
            # safe against the removal each stop triggers (mirrors Async's own
            # Node#stop_children); never dup the list — it's an intrusive linked
            # list and copying it corrupts the nodes.
            root.children&.each(&:stop)
          end
        end
      end
    end
  end
end
