# frozen_string_literal: true

module Neo4j
  module Driver
    module Direct
      # Single-server connection provider for `bolt://` URIs.
      #
      # Sibling of Routing::LoadBalancer — both implement the same interface
      # (acquire / release / verify_connectivity / supports_multi_db? / close)
      # so Driver can hold either polymorphically without branching on scheme.
      #
      # Direct ignores the `access_mode`, `database`, and `bookmarks`
      # kwargs to acquire: all sessions hit the same server, so
      # role/database/bookmark-aware routing is not its concern. The
      # kwargs are accepted so call sites stay polymorphic with
      # Routing::LoadBalancer.
      class ConnectionProvider
        def initialize(uri, auth_manager, options = {})
          @uri = uri
          @auth_manager = auth_manager
          @options = options
        end

        # The current default identity, sourced from the auth-token
        # manager (which refreshes / re-fetches as needed). Sessions
        # re-auth pooled connections to this on acquire unless they carry
        # their own per-session :auth_token.
        def current_auth_token = @auth_manager.get_token

        # Feed a security failure back to the manager. Returns true when
        # the manager considers it retryable (token refreshed), so the
        # caller can re-auth and retry.
        def on_security_exception(token, error) = @auth_manager.handle_security_exception(token, error)

        # imp_user is accepted for signature parity with
        # Routing::LoadBalancer#acquire but unused here: the direct path
        # has no discovery, so impersonation is enforced on RUN/BEGIN by
        # the protocol handler (Bolt::Protocol::Base#enforce_impersonation_support!).
        def acquire(access_mode: nil, database: nil, bookmarks: nil, imp_user: nil, auth: nil)
          # See Routing::LoadBalancer#acquire for the rationale.
          raise Exceptions::IllegalStateException, 'Driver is closed' if @closed

          # `auth` is the per-session override (nil = use the manager's
          # current token). `effective` is the identity this acquire should
          # hand out; resolving it consults the manager (get_auth_count == 1
          # for the default identity, 0 when the session carries its own
          # token). A freshly-built connection authenticates with it directly
          # (no LOGOFF/LOGON); a reused one is re-authed to it via
          # ensure_identity on Bolt 5.1+.
          #
          # On Bolt 5.0 there is no in-place re-auth, so a *reused* connection
          # keeps its creation-time identity. If the manager has since rotated
          # its token, that connection is stale — discard it and loop, letting
          # the pool build a fresh one authenticated as the current identity
          # (Java's backwards-compatible behaviour). Re-resolving `effective`
          # each turn means the replacement issues its own get_token, as the
          # managed-auth contract expects (one extra get_auth per rotation).
          loop do
            effective = auth || @auth_manager.get_token
            conn = pool.pop(auth: effective)
            begin
              ensure_identity(conn, effective, session_auth: auth)
            rescue StandardError
              # Identity enforcement can raise (per-session auth on Bolt < 5.1,
              # or a re-auth LOGON failure). Free the just-checked-out slot
              # instead of leaking it for the driver's lifetime, then re-raise.
              pool.discard(conn)
              raise
            end
            return conn if conn.protocol.supports_re_auth? || conn.auth == effective

            pool.discard(conn)
          end
        end

        def release(connection)
          return unless connection

          # Honor a connection flagged for discard (e.g. after an auth
          # failure) — close it and free the slot rather than pooling a
          # compromised / server-closed connection.
          if connection.discard_on_release
            pool.discard(connection)
          else
            pool.push(connection)
          end
        end

        def verify_connectivity
          release(acquire)
        end

        # True iff the negotiated Bolt protocol supports multi-database
        # routing (Bolt 4.0+). Acquires a connection to ensure HELLO has
        # happened.
        def supports_multi_db?
          conn = acquire
          conn.protocol.supports_multiple_databases?
        ensure
          release(conn)
        end

        # Mirrors Java: a Direct (bolt://) driver has no routing-table
        # registry. testkit's GetRoutingTable / ForcedRoutingTableUpdate
        # handlers expect a clean error here rather than NoMethodError
        # so callers can distinguish "wrong scheme" from a real bug.
        def routing_table_registry
          raise Exceptions::ClientException,
                'Routing table is only available on routing (neo4j://) drivers'
        end

        def close
          @closed = true
          @pool&.shutdown { |conn| conn.close rescue nil }
        end

        private

        # Bring a popped connection to the `effective` identity. A fresh
        # connection was built with it, so authenticate is a no-op; a reused
        # one currently authenticated as somebody else is re-authed (LOGOFF/
        # LOGON, Bolt 5.1+).
        #
        # When `session_auth` is set (per-session token), the identity must
        # be enforceable, so we require Bolt 5.1+ even if the popped
        # connection already happens to hold the token — a 5.0 connection
        # built with the session token would otherwise silently bypass the
        # "per-session auth needs re-auth support" contract. With the default
        # identity, re-auth is applied only where it exists (5.1+); on 5.0 a
        # pooled connection keeps its creation-time token and the manager's
        # refresh reaches new connections instead.
        def ensure_identity(conn, effective, session_auth:)
          # Record whose identity this connection currently holds so a later
          # security failure knows whether to notify the manager. Updated
          # every acquire because a pooled connection changes lessee.
          conn.session_scoped_auth = !session_auth.nil?
          if session_auth
            unless conn.protocol.supports_re_auth?
              raise Exceptions::UnsupportedFeatureException,
                    "Per-session auth requires Bolt 5.1+; negotiated #{conn.protocol.version}"
            end
            conn.authenticate(effective)
          elsif conn.protocol.supports_re_auth?
            conn.authenticate(effective)
          end
        end

        # Bolt::Pool wraps connection_pool's TimedStack primitive
        # and adds the lifetime / liveness / acquisition-timeout gates
        # (see Bolt::Pool docstring). TimedStack is used because, unlike
        # ConnectionPool#checkout, it does NOT cache per-thread — each
        # Session in the same thread must hold its own connection
        # (they can't share server-side transaction state).
        def pool
          @pool ||= Bolt::Pool.new(
            size: max_pool_size,
            options: @options,
            connect_factory: lambda { |auth|
              # `auth` is the per-acquire identity resolved in #acquire and
              # threaded through pool.pop. The `||` is a belt-and-braces
              # fallback for any future pop path that forgets to pass one.
              conn = Bolt::Connection.new(@uri, auth || @auth_manager.get_token, @options).connect
              conn.security_exception_handler = method(:on_security_exception)
              conn
            }
          )
        end

        def max_pool_size
          @options[:max_connection_pool_size] || Driver::DEFAULT_MAX_POOL_SIZE
        end
      end
    end
  end
end
