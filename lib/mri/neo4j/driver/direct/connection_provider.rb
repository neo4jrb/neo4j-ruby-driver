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
        # `domain_name_resolver` is the factory-injected hostname->IPs hook
        # (nil = system DNS); baked into every connection this provider builds.
        def initialize(uri, auth_manager, options = {}, domain_name_resolver: nil, clock: Internal::Clock.new)
          @uri = uri
          @auth_manager = auth_manager
          @options = options
          @clock = clock
          @domain_name_resolver = domain_name_resolver
          # Authorization-expired generation counter (see Connection#auth_epoch).
          # Bumped when any connection reports AuthorizationExpired so every
          # other pooled connection re-authenticates on its next acquire.
          # Guarded by a mutex: the pool is shared across threads and on JRuby
          # (mri-on-jruby) there's no GIL, so a bare `+= 1` could lose bumps.
          @auth_epoch = 0
          @auth_epoch_mutex = Mutex.new
        end

        # Current auth generation, read atomically.
        def auth_epoch = @auth_epoch_mutex.synchronize { @auth_epoch }

        # No home-database resolution on the direct path: a bolt:// driver
        # talks to one server, which resolves the user's home database itself
        # when the operation omits `db`. Returns nil so the session leaves it
        # unset (matches Java's DirectConnectionProvider).
        def home_database(_bookmarks, _imp_user = nil, _auth = nil) = nil

        # The current default identity, sourced from the auth-token
        # manager (which refreshes / re-fetches as needed). Sessions
        # re-auth pooled connections to this on acquire unless they carry
        # their own per-session :auth_token.
        def current_auth_token = @auth_manager.get_token

        # Feed a security failure back to the manager. Returns true when
        # the manager considers it retryable (token refreshed), so the
        # caller can re-auth and retry. An AuthorizationExpired failure also
        # bumps the auth epoch: the server dropped its authorization cache
        # for this identity, so every pooled connection must re-authenticate
        # (with whatever token is current) before its next use.
        def on_security_exception(token, error, session_scoped = false)
          # Provider-side invalidation happens regardless of who owns the token.
          @auth_epoch_mutex.synchronize { @auth_epoch += 1 } if error.is_a?(Exceptions::AuthorizationExpiredException)
          # A per-session token wasn't issued by the manager — don't notify it
          # (testkit: handle_security_exception_count stays 0), and don't treat
          # the failure as manager-retryable.
          return false if session_scoped

          @auth_manager.handle_security_exception(token, error)
        end

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
            # Snapshot the epoch once per turn so the staleness check and the
            # connection's stamp (in ensure_identity) use one consistent value.
            epoch = auth_epoch
            effective = auth || @auth_manager.get_token
            conn = pool.pop(auth: effective)
            begin
              ensure_identity(conn, effective, session_auth: auth, epoch: epoch)
            rescue StandardError
              # Identity enforcement can raise (per-session auth on Bolt < 5.1,
              # or a re-auth LOGON failure). Free the just-checked-out slot
              # instead of leaking it for the driver's lifetime, then re-raise.
              pool.discard(conn)
              raise
            end
            # On Bolt 5.1+ ensure_identity already brought the connection to
            # the right identity (and re-auth generation). On 5.0 it can't, so
            # a reused connection is only usable if its token AND auth epoch
            # already match — otherwise discard and let the pool rebuild a
            # fresh one (token rotation, or an AuthorizationExpired refresh).
            return conn if conn.protocol.supports_re_auth? ||
                           (conn.auth == effective && conn.auth_epoch == epoch)

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
          # Probe the connection with a RESET so a reused (pooled) connection
          # is actually exercised on the wire — matches Java's
          # verifyConnectivity and the routing LoadBalancer, and testkit's
          # test_direct_from_pool (which asserts one RESET on the pooled
          # connection). `propagate: true` surfaces a failed probe (rather than
          # reporting false success); a failed probe means a dead connection,
          # so discard it instead of returning it to the pool.
          conn = acquire
          begin
            conn.reset!(propagate: true)
          rescue StandardError
            pool.discard(conn)
            raise
          end
          release(conn)
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
        def ensure_identity(conn, effective, session_auth:, epoch: auth_epoch)
          # Record whose identity this connection currently holds so a later
          # security failure knows whether to notify the manager. Updated
          # every acquire because a pooled connection changes lessee.
          conn.session_scoped_auth = !session_auth.nil?
          # Force a re-auth (even to the same token) when this connection was
          # authed before the latest AuthorizationExpired — the server needs
          # a fresh LOGON to rebuild its authorization cache.
          force = conn.auth_epoch < epoch
          if session_auth
            unless conn.protocol.supports_re_auth?
              raise Exceptions::UnsupportedFeatureException,
                    "Per-session auth requires Bolt 5.1+; negotiated #{conn.protocol.version}"
            end
            conn.authenticate(effective, force: force)
            conn.auth_epoch = epoch
          elsif conn.protocol.supports_re_auth?
            conn.authenticate(effective, force: force)
            conn.auth_epoch = epoch
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
            clock: @clock,
            connect_factory: lambda { |auth|
              # `auth` is the per-acquire identity resolved in #acquire and
              # threaded through pool.pop. The `||` is a belt-and-braces
              # fallback for any future pop path that forgets to pass one.
              conn = Bolt::Connection.new(@uri, auth || @auth_manager.get_token, @options,
                                          domain_name_resolver: @domain_name_resolver, clock: @clock).connect
              conn.security_exception_handler = method(:on_security_exception)
              # A freshly-authenticated connection belongs to the current
              # auth generation, so ensure_identity won't force-re-auth it.
              conn.auth_epoch = auth_epoch
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
