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
          @factory = connect_factory
          @stack = ConnectionPool::TimedStack.new(size: size, &connect_factory)
        end

        # Pop a connection that's young enough and confirmed alive.
        # Loops until a usable one is found or the acquisition-timeout
        # budget runs out — every discarded slot opens room for the
        # factory to make a fresh one.
        def pop
          deadline = current_monotonic + acquisition_timeout
          loop do
            timeout = [deadline - current_monotonic, 0].max
            conn = @stack.pop(timeout: timeout)
            return prepare(conn) if usable?(conn)

            discard(conn)
            # Loop with whatever budget remains. A flapping server
            # would otherwise burn the whole pool in one acquire.
          end
        rescue ::Timeout::Error
          raise Exceptions::ClientException,
                "Unable to acquire connection from the pool within configured maximum time of #{format_acquisition_timeout}"
        end

        def push(connection)
          return unless connection

          connection.idle_since = current_monotonic
          @stack.push(connection)
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
          return false if needs_liveness_check?(conn) && !conn.alive?

          true
        end

        def prepare(conn)
          conn.idle_since = nil
          conn
        end

        def discard(conn)
          conn&.close
        rescue StandardError
          # Caller already has a fresh connection coming from the
          # factory; a failure during close is noise.
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
