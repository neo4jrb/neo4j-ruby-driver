# frozen_string_literal: true

module Neo4j
  module Driver
    module Routing
      # Routing-aware connection provider. Mirrors the design of Java's
      # RoutingTableHandlerImpl + LoadBalancer and Python's Neo4jPool:
      #
      # - Per-database RoutingTable cache, mutated through @refresh_lock.
      # - Per-server connection pools (TimedStack), keyed by ServerAddress.
      # - acquire(access_mode:) ensures the table is fresh, then loops
      #   selecting an address and opening a connection; on connection
      #   failure the address is `deactivate`d (forgotten from every
      #   table + per-server pool torn down) and we retry until the role
      #   bucket is exhausted.
      # - Connections handed out are wrapped in RoutedConnection so the
      #   pool gets called back on write-side leader changes (NotALeader,
      #   ForbiddenOnReadOnlyDatabase) and stale-server connection errors.
      class LoadBalancer
        ROUTING_CONTEXT_RESERVED_KEYS = %w[address].freeze

        # Codes that mean "this is a client mistake, retrying the
        # routing fetch against another router won't help, fail fast".
        # Matches Python's Neo4jError._is_fatal_during_discovery.
        FATAL_DISCOVERY_CODES = %w[
          Neo.ClientError.Database.DatabaseNotFound
          Neo.ClientError.Transaction.InvalidBookmark
          Neo.ClientError.Transaction.InvalidBookmarkMixture
          Neo.ClientError.Statement.TypeError
          Neo.ClientError.Statement.ArgumentError
          Neo.ClientError.Request.Invalid
        ].freeze

        # `domain_name_resolver` is the factory-injected hostname->IPs hook
        # (nil = system DNS); baked into every connection this balancer builds.
        def initialize(uri, auth_manager, options = {}, domain_name_resolver: nil, clock: Internal::Clock.new)
          @uri = uri
          @auth_manager = auth_manager
          @options = options
          @clock = clock
          @domain_name_resolver = domain_name_resolver
          @routing_context = parse_routing_context(uri)
          @pools = {}                      # ServerAddress => ConnectionPool::TimedStack
          @routing_tables = {}             # database (str or nil) => RoutingTable
          @cursor = Hash.new(0)            # round-robin per (database, role)
          # Per-server authorization-expired generation counters (see
          # Connection#auth_epoch and Direct::ConnectionProvider). Bumped for a
          # server when one of its connections reports AuthorizationExpired, so
          # the OTHER connections to that same server re-authenticate on their
          # next acquire. Scoped per-address (not driver-wide) because the
          # server's authorization cache is per-server — a reader's expiry must
          # not force the writer pool to re-auth.
          @auth_epochs = Hash.new(0)
          # Monitor (reentrant) because ensure_routing_table_is_fresh holds
          # the lock while it goes through pool_for, which also locks.
          @refresh_lock = Monitor.new
        end

        # Open (or pop) a connection appropriate for `access_mode` against
        # `database` (nil = home db). Loops: select an address, try to
        # acquire, deactivate on connection failure and try again. Raises
        # ServiceUnavailableException only when the role bucket has been
        # exhausted by deactivations.
        def acquire(access_mode: :write, database: nil, bookmarks: nil, imp_user: nil, auth: nil)
          # Fast-fail with IllegalStateException for use-after-close.
          # Otherwise the next routing fetch would propagate a generic
          # Connection-refused ServiceUnavailableException, masking the
          # actual bug in the caller's lifecycle.
          raise Exceptions::IllegalStateException, 'Driver is closed' if @closed

          access_mode = access_mode.to_sym
          # `auth` is the per-session override (nil = manager's current
          # token). The worker identity is resolved per turn inside the loop
          # below, not once here: on Bolt 5.0 an acquire that discards a
          # token-rotated connection must re-consult the manager so the
          # replacement issues its own get_token (mirrors
          # Direct::ConnectionProvider — one extra get_auth per rotation).
          # Discovery resolves its own identity independently, so a routed
          # acquire with the default token consults the manager twice
          # (get_auth_count == 2): once for the ROUTE connection, once for the
          # worker. A session-carried token short-circuits both (count 0).
          #
          # imp_user is threaded into discovery so the ROUTE call enforces
          # impersonation support (Bolt 4.4+) against the router, matching
          # the RUN/BEGIN path — see Connection#route. `auth` is threaded so
          # the ROUTE connection authenticates as the session's identity
          # (per-session token) rather than always the manager's default.
          # Resolve to the concrete database name: for a home-db acquire
          # (database == nil) discovery returns the resolved name, which keys
          # the table and the address selection below.
          resolved_database = ensure_routing_table_is_fresh(
            database, access_mode, bookmarks: bookmarks, imp_user: imp_user, auth: auth
          ).database

          last_error = nil
          loop do
            address = select_address(resolved_database, access_mode)
            unless address
              # Routing table yielded no usable server for this mode —
              # a session-expired condition (the session can't be served,
              # caller should get a fresh one), even if the last attempt
              # failed with a connection-level ServiceUnavailable. Surface
              # SessionExpired with that as the cause (matches Java).
              # Explicit cause: this raise is outside the per-address
              # rescue, so $! would not auto-populate it. cause: nil is
              # fine when there was no connection-level failure.
              raise Exceptions::SessionExpiredException,
                    "No #{access_mode} servers available for database #{resolved_database.inspect}",
                    cause: last_error
            end

            pool = pool_for(address)
            begin
              epoch = auth_epoch_for(address)
              # Re-resolve per turn (see acquire header): a discard-and-retry
              # on Bolt 5.0 token rotation must issue its own get_token.
              effective = auth || @auth_manager.get_token
              inner = pool.pop(auth: effective)
              begin
                ensure_identity(inner, effective, session_auth: auth, address: address, epoch: epoch)
              rescue StandardError
                # Don't leak the worker slot if identity enforcement fails
                # (per-session auth on Bolt < 5.1, or a re-auth LOGON
                # failure); discard it, then let the error propagate.
                discard(address, inner)
                raise
              end
              # On Bolt 5.0 ensure_identity can't re-auth in place, so a
              # reused connection whose token or auth epoch is stale (token
              # rotation, or an AuthorizationExpired refresh) must be discarded
              # and replaced by a fresh one — mirrors Direct::ConnectionProvider.
              unless inner.protocol.supports_re_auth? ||
                     (inner.auth == effective && inner.auth_epoch == epoch)
                discard(address, inner)
                next
              end
              return RoutedConnection.new(self, inner, address, access_mode, resolved_database)
            rescue Exceptions::ServiceUnavailableException => e
              # Server is unreachable (open_connection raised inside the
              # pool's create block). Drop the address from every table
              # and tear down its pool; loop and try another address.
              last_error = e
              deactivate(address)
            end
          end
        end

        # Current default identity from the auth-token manager (refreshes
        # as needed); on_security_exception feeds a failure back to it.
        # Mirror Direct::ConnectionProvider so Session stays polymorphic.
        # Resolve the user's home database (database == nil): the ROUTE
        # response carries the resolved name in `db` (Bolt 4.4+/5.x), which
        # the routing table records as its `database`. The session uses the
        # resolved name on RUN/BEGIN so the server doesn't re-resolve it per
        # op. nil on the procedure path (3.0/4.0-4.2 have no db in the reply),
        # where the server resolves the home db from a null `db` itself.
        def home_database(bookmarks, imp_user = nil, auth = nil)
          # Same use-after-close guard as #acquire: home-db resolution routes
          # too, so a closed driver must fast-fail with IllegalStateException
          # rather than re-routing into a Connection-refused
          # ServiceUnavailableException. This is the ONLY routing entry for the
          # single-database path (Bolt 3.0, database == nil) — it never reaches
          # #acquire's guard — so without this a post-close session.run on a 3.0
          # routing driver surfaced the wrong error type.
          raise Exceptions::IllegalStateException, 'Driver is closed' if @closed

          ensure_routing_table_is_fresh(nil, :read, bookmarks: bookmarks, imp_user: imp_user, auth: auth).database
        end

        def current_auth_token = @auth_manager.get_token

        def on_security_exception(address, token, error, session_scoped = false)
          # See Direct::ConnectionProvider#on_security_exception: an expired
          # authorization cache forces the OTHER connections to that same
          # server to re-auth. Provider-side, so it runs regardless of who
          # owns the token; the manager notification is skipped for a
          # per-session identity.
          @refresh_lock.synchronize { @auth_epochs[address] += 1 } if error.is_a?(Exceptions::AuthorizationExpiredException)
          return false if session_scoped

          @auth_manager.handle_security_exception(token, error)
        end

        # Current auth generation for a server, read under the lock that guards
        # the @auth_epochs Hash (mutated in on_security_exception).
        def auth_epoch_for(address) = @refresh_lock.synchronize { @auth_epochs[address] }

        def release(connection)
          # Direct provider tolerates nil; mirror that. Internal callers
          # always release a RoutedConnection but guard so the wrong
          # type doesn't NoMethodError later.
          return unless connection.respond_to?(:discard_on_release)

          if connection.discard_on_release
            discard(connection.address_obj, connection.inner)
            return
          end

          @refresh_lock.synchronize do
            pool = @pools[connection.address_obj]
            pool&.push(connection.inner)
          end
        end

        # Routing-aware verify_connectivity: force-refresh the routing
        # table, then probe *any* reader to confirm the cluster is
        # reachable. RESET so the borrowed connection lands back in the
        # pool in a known-clean state (matches testkit's
        # `test_routing_from_pool` expectation of one RESET per probe).
        def verify_connectivity
          invalidate_routing_table(nil)
          conn = acquire(access_mode: :read)
          begin
            # propagate: a failed probe means a dead reader — surface it and
            # discard the connection rather than pooling it (see
            # Direct::ConnectionProvider#verify_connectivity).
            conn.reset!(propagate: true)
          rescue StandardError
            conn.discard_on_release = true
            release(conn)
            raise
          end
          release(conn)
        end

        # Per-server-address pool snapshots (driver.metrics). One entry per
        # server we hold a pool for; the address key is the Routing::ServerAddress
        # the pool was created under.
        def connection_pool_metrics
          @refresh_lock.synchronize do
            @pools.map do |address, pool|
              in_use, idle = pool.metrics_snapshot
              Internal::Metrics::ConnectionPoolMetrics.new(address, in_use, idle)
            end
          end
        end

        # Routing requires Bolt 4.0+ (the ROUTE message and `CALL
        # dbms.routing.getRoutingTable` are 4.0+ features). If we got
        # this far the answer is always true.
        # Multi-database support is a property of the negotiated Bolt
        # version (4.0+), not of routing per se — a neo4j:// driver against a
        # 3.0 cluster still routes (via the getRoutingTable procedure) but
        # does NOT support multiple databases. Probe an actual connection's
        # protocol, mirroring Direct::ConnectionProvider. The acquire does
        # discovery + a reader HELLO (no query), then the connection is
        # released straight back to the pool.
        def supports_multi_db?
          conn = acquire(access_mode: :read)
          conn.protocol.supports_multiple_databases?
        ensure
          release(conn) if conn
        end

        def close
          @refresh_lock.synchronize do
            @closed = true
            @pools.each_value { |pool| pool.shutdown { |conn| conn.close rescue nil } }
            @pools.clear
            @routing_tables.clear
          end
        end

        # Internal — mirrors Java's
        # ConnectionProvider#getRoutingTableRegistry(). LoadBalancer is
        # both the connection provider and the routing-table registry;
        # the layer split exists in Java mostly because it predates
        # generics. Used by testkit's GetRoutingTable handler.
        def routing_table_registry = self

        # Internal — mirrors Java's
        # RoutingTableRegistry#getRoutingTableHandler(databaseName).
        # Pure read: returns the cached table for the database, or a
        # new empty placeholder if no table has ever been fetched.
        # (Empty means routers/readers/writers are all empty — it is
        # NOT `fresh?`; callers that want a fetched table go through
        # ensure_routing_table_is_fresh.) Deliberately does NOT force
        # a fetch — testkit's get_routing_table contract is "what's
        # currently known", and an auto-fetch here causes a second
        # ROUTE on a stub server that already hung up after the first
        # (see test_should_fail_on_routing_table_with_no_reader).
        def routing_table_handler(database)
          @refresh_lock.synchronize do
            Handler.new(@routing_tables[database] || RoutingTable.new(database: database, clock: @clock))
          end
        end

        # Internal — force a fresh ROUTE call for the given database
        # regardless of TTL/cache. Used by ForcedRoutingTableUpdate
        # testkit handler. Threads bookmarks through to the ROUTE
        # payload so causal-consistency assertions work.
        def refresh(database, bookmarks = nil)
          @refresh_lock.synchronize do
            invalidate_routing_table(database)
            update_routing_table(database, bookmarks: bookmarks)
          end
        end

        # Mirrors org.neo4j.driver.internal.cluster.RoutingTableHandler
        # for the slim surface testkit reads (just .routing_table).
        Handler = Struct.new(:routing_table)

        # Called by RoutedConnection on a fatal connection-level error
        # (or DatabaseUnavailable). Removes the address from every
        # database's routing table and tears down its connection pool.
        def deactivate(address)
          @refresh_lock.synchronize do
            @routing_tables.each_value { |table| table.forget(address) }
            pool = @pools.delete(address)
            pool&.shutdown { |conn| conn.close rescue nil }
          end
        end

        # Called by RoutedConnection on a write-mode operation that hit
        # NotALeader / ForbiddenOnReadOnlyDatabase. The server is alive
        # but no longer the leader for this db — drop it from the writers
        # bucket only; routers/readers stay.
        def on_write_failure(address, database)
          @refresh_lock.synchronize do
            @routing_tables[database]&.forget_writer(address)
          end
        end

        private

        def parse_routing_context(uri)
          context = {}
          unless uri.query.nil? || uri.query.empty?
            URI.decode_www_form(uri.query).each do |k, v|
              raise ArgumentError, "Routing context key '#{k}' is reserved" if ROUTING_CONTEXT_RESERVED_KEYS.include?(k)

              context[k.to_sym] = v
            end
          end
          # Seed `address` is always part of the routing context, regardless
          # of whether the URI carried query params. Otherwise the ROUTE
          # payload silently differs between `neo4j://host` and
          # `neo4j://host?k=v`.
          context[:address] = "#{uri.host}:#{uri.port || ServerAddress::DEFAULT_PORT}"
          context
        end

        # Make sure a usable routing table exists for `database` and the
        # requested `access_mode`. Cheap fast path when the cached table
        # is still fresh; otherwise fetches one inside the lock with a
        # second freshness check (double-checked locking pattern matches
        # Python's ensure_routing_table_is_fresh). Optional `bookmarks`
        # are threaded into the ROUTE payload.
        def ensure_routing_table_is_fresh(database, access_mode, bookmarks: nil, imp_user: nil, auth: nil)
          @refresh_lock.synchronize do
            table = @routing_tables[database]
            return table if table && table.fresh?(readonly: access_mode == :read)

            update_routing_table(database, bookmarks: bookmarks, imp_user: imp_user, auth: auth)
          end
        end

        def invalidate_routing_table(database)
          @refresh_lock.synchronize { @routing_tables.delete(database) }
        end

        # Refresh the routing table from a router. Routers are tried in
        # priority order: prefer the seed address if we have no table or
        # the existing table came back without writers (likely-stale),
        # otherwise prefer the existing routers list first. Each failed
        # router is `deactivate`d before moving on to the next.
        def update_routing_table(database, bookmarks: nil, imp_user: nil, auth: nil)
          existing = @routing_tables[database]
          prefer_seed = existing.nil? || existing.initialized_without_writers

          errors = []
          routers_in_order(existing, prefer_seed: prefer_seed).each do |router|
            new_table = fetch_routing_table_from(router, database, bookmarks, errors, imp_user, auth)
            next unless new_table

            apply_routing_table(new_table)
            return @routing_tables[new_table.database]
          end

          last = errors.last
          raise Exceptions::ServiceUnavailableException.new(
            "Unable to retrieve routing information for database #{database.inspect}: " \
            "tried #{errors.length} router(s) without success" \
            "#{last ? " (last: #{last.message})" : ''}",
            suppressed: errors
          )
        end

        def routers_in_order(existing, prefer_seed:)
          seeds = resolved_seed_routers
          existing_others = existing ? existing.routers.to_a - seeds : []
          prefer_seed ? [*seeds, *existing_others] : [*existing_others, *seeds]
        end

        # The seed router(s) to bootstrap discovery from. A custom address
        # resolver (Config#resolver, Java's ServerAddressResolver) expands the
        # driver's URI address into the set of initial routers — re-resolved
        # on every rediscovery so a changed cluster membership / router IP is
        # picked up. Without a resolver the single URI address is the only
        # seed. (Hostname->IP resolution is a separate, connect-time concern;
        # see Bolt::Connection#resolved_addresses.)
        def resolved_seed_routers
          seed = seed_router
          return [seed] unless (resolver = @options[:resolver])

          Array(resolver.call(seed.to_s)).map { |addr| ServerAddress.parse(addr.to_s) }
        end

        def seed_router
          ServerAddress.parse("#{@uri.host}:#{@uri.port || ServerAddress::DEFAULT_PORT}")
        end

        # Returns a new RoutingTable on success, nil on a per-router
        # failure. Connection-level failures additionally `deactivate`
        # the router; protocol-level failures (e.g. ClientException
        # while routing) just record the error so the caller tries the
        # next router.
        def fetch_routing_table_from(router, database, bookmarks, errors, imp_user = nil, auth = nil)
          pool = pool_for(router)
          conn = nil
          begin
            # Discovery's identity is resolved per turn inside the loop below
            # (per-session token short-circuits the manager consult). It sets
            # BOTH the fresh-connection token and the re-auth of a reused
            # router connection: pool.pop(auth:) only sets a *fresh*
            # connection's identity, so without ensure_identity a reused
            # ROUTE connection would run under the previous lessee's user
            # (and skip the Bolt 5.1 gate for per-session auth). Re-resolving
            # each turn means a Bolt 5.0 discard-and-rebuild on token rotation
            # issues its own get_token, matching the worker path in #acquire.
            # pop is inside the begin block on purpose: open_connection
            # is the pool's create block and can raise ServiceUnavailable
            # (router unreachable). If that escaped the method,
            # update_routing_table's iteration over remaining routers
            # would stop on the first unreachable one.
            #
            # Loop for the same Bolt 5.0 reason as the worker path in #acquire:
            # a reused router connection that can't re-auth in place and whose
            # token/epoch is stale (rotation, AuthorizationExpired) is discarded
            # and rebuilt rather than ROUTEing under a stale identity.
            loop do
              epoch = auth_epoch_for(router)
              effective = auth || @auth_manager.get_token
              conn = pool.pop(auth: effective)
              ensure_identity(conn, effective, session_auth: auth, address: router, epoch: epoch)
              break if conn.protocol.supports_re_auth? ||
                       (conn.auth == effective && conn.auth_epoch == epoch)

              discard(router, conn)
              conn = nil
            end
            rt = conn.route(database: database, bookmarks: Array(bookmarks),
                            imp_user: imp_user, routing_context: @routing_context)
            new_table = RoutingTable.from_response(symbolize(rt), database, clock: @clock)

            if new_table.routers.empty? || new_table.readers.empty?
              errors << Exceptions::ServiceUnavailableException.new(
                "Router #{router} returned a routing table with no " \
                "#{new_table.routers.empty? ? 'routers' : 'readers'}"
              )
              pool.push(conn)
              return nil
            end

            pool.push(conn)
            new_table
          rescue Exceptions::ServiceUnavailableException, ::Timeout::Error => e
            errors << e
            # Connection (if any) is presumed dead; deactivate tears
            # down the pool so the conn's `created` slot is reclaimed.
            conn&.close rescue nil
            deactivate(router)
            nil
          rescue Exceptions::Neo4jException => e
            # Connection is in FAILED state; drop it before we either
            # re-raise (fatal) or try the next router (transient).
            discard(router, conn) if conn
            raise if fatal_during_discovery?(e)

            errors << e
            nil
          end
        end

        # A subset of Neo.ClientError.* codes means the request itself
        # is unsatisfiable — retrying against a different router can't
        # help. Propagate immediately so the caller sees the original
        # exception class and code rather than a wrapped
        # ServiceUnavailableException with the original buried in
        # `suppressed`. Mirrors Python's _is_fatal_during_discovery.
        def fatal_during_discovery?(error)
          code = error.code.to_s
          return true if FATAL_DISCOVERY_CODES.include?(code)

          # A client-side ClientException carries no server code — it was
          # raised by the driver while building the request (e.g.
          # impersonation over a pre-4.4 protocol), so it is identical on
          # every router and retrying can't help. Propagate it rather than
          # collecting it and masking it as a ServiceUnavailableException.
          return true if code.empty? && error.is_a?(Exceptions::ClientException)

          code.start_with?('Neo.ClientError.Security.') &&
            code != 'Neo.ClientError.Security.AuthorizationExpired'
        end

        # Cache the fetched table under its resolved database name. For an
        # explicit-database acquire the resolved name equals the request; for a
        # home-db acquire (requested nil) it is the name the router resolved, so
        # home-db tables are keyed by their real name, never under nil.
        def apply_routing_table(new_table)
          database = new_table.database
          existing = @routing_tables[database]
          if existing
            existing.update(new_table)
          else
            @routing_tables[database] = new_table
          end
        end

        # Round-robin within the role bucket of the table for `database`.
        # Returns nil when the bucket is empty (typically after one or
        # more deactivations during the acquire loop).
        def select_address(database, access_mode)
          @refresh_lock.synchronize do
            table = @routing_tables[database] or return nil
            servers = table.servers_for(access_mode).to_a
            return nil if servers.empty?

            key = [database, access_mode]
            address = servers[@cursor[key] % servers.size]
            @cursor[key] += 1
            address
          end
        end

        # Close a checked-out connection without putting it back. Used
        # when the connection is in a known-bad state (server FAILED,
        # write-failure on a NotALeader, etc.) so we don't poison the
        # pool. Bolt::Pool#discard closes and frees the slot so the
        # next pop can lazily build a fresh one.
        def discard(address, conn)
          @refresh_lock.synchronize do
            @pools[address]&.discard(conn)
          end
        end

        def pool_for(address)
          @refresh_lock.synchronize do
            @pools[address] ||= Bolt::Pool.new(
              size: max_pool_size,
              options: @options,
              clock: @clock,
              connect_factory: ->(auth) { open_connection(address, auth) }
            )
          end
        end

        def open_connection(address, auth = nil)
          # Preserve the encryption suffix: neo4j+s → bolt+s,
          # neo4j+ssc → bolt+ssc, neo4j → bolt. Otherwise routing
          # connections to a TLS cluster would open plaintext and the
          # server would reject the non-TLS first record.
          uri = "#{@uri.scheme.sub('neo4j', 'bolt')}://#{address}"
          # routing_context goes into the HELLO map so the cluster can
          # apply the configured policy / region (the same routing
          # context is sent to readers/writers too; non-router servers
          # just ignore it).
          opts = @options.merge(routing_context: @routing_context)
          # `auth` is the per-acquire identity (per-session token or the
          # worker's resolved token). Fall back to the manager's current
          # token for acquires that don't carry one (verify_connectivity).
          conn = Bolt::Connection.new(uri, auth || @auth_manager.get_token, opts,
                                      domain_name_resolver: @domain_name_resolver, clock: @clock).connect
          # Bind the security handler to this connection's server so an
          # AuthorizationExpired bumps the right per-address epoch.
          conn.security_exception_handler =
            ->(token, error, session_scoped = false) { on_security_exception(address, token, error, session_scoped) }
          # A freshly-authenticated connection belongs to the current auth
          # generation for its server, so ensure_identity won't force-re-auth it.
          conn.auth_epoch = auth_epoch_for(address)
          conn
        end

        # Bring a popped worker connection to the `effective` identity —
        # no-op for a fresh connection (built with it), LOGOFF/LOGON for a
        # reused one. Mirrors Direct::ConnectionProvider#ensure_identity;
        # see there for the session-auth-needs-5.1 rationale.
        def ensure_identity(conn, effective, session_auth:, address:, epoch: nil)
          # See Direct::ConnectionProvider#ensure_identity — tag the
          # connection's current identity so security failures only notify
          # the manager for the manager's own (default) token, and force a
          # re-auth when this connection predates the latest AuthorizationExpired
          # for its server.
          conn.session_scoped_auth = !session_auth.nil?
          epoch ||= auth_epoch_for(address)
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

        def symbolize(value)
          case value
          when Hash  then value.transform_keys(&:to_sym).transform_values { symbolize(it) }
          when Array then value.map { symbolize(it) }
          else value
          end
        end

        def max_pool_size
          @options[:max_connection_pool_size] || Driver::DEFAULT_MAX_POOL_SIZE
        end

      end
    end
  end
end
