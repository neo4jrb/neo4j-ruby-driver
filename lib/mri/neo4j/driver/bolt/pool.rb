# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Hardened connection pool. Wraps ConnectionPool::TimedStack and
      # layers the three guarantees production callers care about:
      #
      #   max_connection_lifetime  → connections older than this are
      #                              dropped on acquire (caps server-side
      #                              resource growth for long-running
      #                              processes).
      #   connection_liveness_check_timeout → if a connection has been
      #                              idle longer than this, RESET-probe
      #                              before handing it out (catches
      #                              "server reaped me, client didn't
      #                              notice yet").
      #   connection_acquisition_timeout → bounded wait when the pool
      #                              is at its size cap (raises
      #                              ClientException, not a hang).
      #
      # Mirrors org.neo4j.driver.internal.async.pool.NettyChannelPool
      # in the Java reference. The acquisition-timeout slice was already
      # in place via TimedStack; this class adds the lifetime + liveness
      # gates and centralises the construction across the two providers.
      class Pool
        DEFAULT_ACQUISITION_TIMEOUT = 60

        # `connect_factory` is a callable returning a freshly-opened
        # Bolt::Connection. Wrapped, not inherited, because TimedStack
        # owns the threading + size-cap primitive and doesn't expose
        # hooks for "decide whether to hand out the popped item".
        def initialize(size:, options:, connect_factory:)
          @options = options
          # connect_factory takes the auth token a fresh connection should
          # authenticate with. pop hands it to the create block via a
          # thread-local: the create block runs synchronously inside
          # @stack.pop on the *calling* thread, so a thread-local is read
          # back by the same thread that set it and can't be clobbered by a
          # concurrent pop on another thread (a shared ivar could — this
          # pool is shared across sessions). Keyed by object_id so distinct
          # pools don't collide on the same thread. This lets a session
          # create a fresh connection with its own identity (per-session
          # auth) or the manager's current token in a single get_token call,
          # instead of connecting as the manager and re-authing.
          @connect_factory = connect_factory
          @auth_key = :"bolt_pool_next_auth_#{object_id}"
          @stack = ConnectionPool::TimedStack.new(size: size) { @connect_factory.call(Thread.current[@auth_key]) }
        end

        # Pop a connection that's young enough and confirmed alive.
        # Loops until a usable one is found or the acquisition-timeout
        # budget runs out — every discarded slot opens room for the
        # factory to make a fresh one.
        def pop(auth: nil)
          # The token a freshly-built connection should authenticate with,
          # handed to the create block via a thread-local that lives only
          # for this pop (see #initialize). Cleared in `ensure` so it never
          # leaks into a later create on the same thread.
          Thread.current[@auth_key] = auth
          deadline = current_monotonic + acquisition_timeout
          loop do
            timeout = [deadline - current_monotonic, 0].max
            conn = @stack.pop(timeout: timeout)
            return prepare(conn) if usable?(conn)

            discard_on_pop(conn)
            # Loop with whatever budget remains. A flapping server
            # would otherwise burn the whole pool in one acquire.
          end
        rescue ::Timeout::Error
          raise Exceptions::ClientException,
                "Unable to acquire connection from the pool within configured maximum time of #{format_acquisition_timeout}"
        ensure
          Thread.current[@auth_key] = nil
        end

        def push(connection)
          return unless connection

          connection.idle_since = current_monotonic
          @stack.push(connection)
        end

        # Close a checked-out connection without putting it back.
        # Mirrors Java's pool-discard: used when the connection is in
        # a known-bad state (server FAILED, write-failure on a
        # NotALeader, etc.) so we don't poison the pool. Frees the
        # TimedStack slot so the next pop can lazily build a fresh
        # one.
        def discard(connection)
          close_quietly(connection)
          @stack.decrement_created
        end

        def shutdown(&block)
          @stack.shutdown(&block)
        end

        private

        # Both gates: too old OR known dead. We probe only when the
        # connection has been idle past the liveness threshold so the
        # hot path stays single-pop / no-extra-roundtrip.
        def usable?(conn)
          return false if conn.nil?
          return false if conn.closed?
          return false if expired?(conn)
          # A reused connection (idle_since set when it was pushed back) may have
          # been closed by the server while parked — a cheap non-blocking
          # peer-close check, no round-trip, catches that so we don't hand out a
          # dead connection (and the replacement re-resolves the address). Fresh
          # connections (idle_since nil) skip it.
          return false if conn.idle_since && conn.broken?
          return false if needs_liveness_check?(conn) && !conn.alive?

          true
        end

        def prepare(conn)
          conn.idle_since = nil
          conn
        end

        # Replacement-on-acquire close: TimedStack already counted
        # this connection as "created" (whether it came from the stack
        # or the factory), so we must decrement_created to free the
        # slot — otherwise a saturated pool that keeps producing
        # unusable connections deadlocks: the next pop sees @created
        # == size, has nothing on the stack, and blocks until timeout.
        def discard_on_pop(conn)
          close_quietly(conn)
          @stack.decrement_created
        end

        def close_quietly(conn)
          conn&.close
        rescue StandardError
          # Caller already has a fresh connection coming. A failure
          # during close is noise.
        end

        def expired?(conn)
          return false unless max_lifetime
          return false unless conn.created_at

          current_monotonic - conn.created_at > max_lifetime
        end

        def needs_liveness_check?(conn)
          return false unless liveness_check_timeout
          return false unless conn.idle_since

          current_monotonic - conn.idle_since > liveness_check_timeout
        end

        def max_lifetime
          @max_lifetime ||= seconds(@options[:max_connection_lifetime])
        end

        def liveness_check_timeout
          # Memoise the sentinel separately from the value so a configured
          # 0 (probe-every-time) still bypasses the recompute.
          return @liveness_check_timeout if defined?(@liveness_check_timeout)

          @liveness_check_timeout = seconds(@options[:connection_liveness_check_timeout])
        end

        def acquisition_timeout
          @acquisition_timeout ||=
            seconds(@options[:connection_acquisition_timeout]) || DEFAULT_ACQUISITION_TIMEOUT
        end

        # Accept Numeric seconds or ActiveSupport::Duration (which
        # responds to #to_f). nil stays nil — callers gate on it to
        # decide whether the feature is configured at all.
        def seconds(value)
          value&.to_f
        end

        def format_acquisition_timeout
          "#{(acquisition_timeout * 1000).to_i}ms"
        end

        def current_monotonic
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
