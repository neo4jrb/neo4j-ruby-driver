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

        def initialize(uri, auth, options = {})
          @uri = uri
          @auth = auth
          @options = options
          @routing_context = parse_routing_context(uri)
          @pools = {}                      # ServerAddress => ConnectionPool::TimedStack
          @routing_tables = {}             # database (str or nil) => RoutingTable
          @cursor = Hash.new(0)            # round-robin per (database, role)
          # Monitor (reentrant) because ensure_routing_table_is_fresh holds
          # the lock while it goes through pool_for, which also locks.
          @refresh_lock = Monitor.new
        end

        # Open (or pop) a connection appropriate for `access_mode` against
        # `database` (nil = home db). Loops: select an address, try to
        # acquire, deactivate on connection failure and try again. Raises
        # ServiceUnavailableException only when the role bucket has been
        # exhausted by deactivations.
        def acquire(access_mode: :write, database: nil, bookmarks: nil)
          # Fast-fail with IllegalStateException for use-after-close.
          # Otherwise the next routing fetch would propagate a generic
          # Connection-refused ServiceUnavailableException, masking the
          # actual bug in the caller's lifecycle.
          raise Exceptions::IllegalStateException, 'Driver is closed' if @closed

          access_mode = access_mode.to_sym
          ensure_routing_table_is_fresh(database, access_mode, bookmarks: bookmarks)

          last_error = nil
          loop do
            address = select_address(database, access_mode)
            unless address
              raise last_error || Exceptions::SessionExpiredException.new(
                "No #{access_mode} servers available for database #{database.inspect}"
              )
            end

            pool = pool_for(address)
            begin
              inner = pool.pop(timeout: acquisition_timeout_seconds)
              return RoutedConnection.new(self, inner, address, access_mode, database)
            rescue Exceptions::ServiceUnavailableException => e
              # Server is unreachable (open_connection raised inside the
              # pool's create block). Drop the address from every table
              # and tear down its pool; loop and try another address.
              last_error = e
              deactivate(address)
            rescue ::Timeout::Error
              # Pool exhaustion at max_pool_size, not a server failure.
              # Mirrors Direct::ConnectionProvider#acquire so the user
              # sees the same actionable error regardless of scheme.
              raise Exceptions::ClientException,
                    "Unable to acquire connection from the pool within configured maximum time of #{format_acquisition_timeout}"
            end
          end
        end

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
          conn.reset!
          release(conn)
        end

        # Routing requires Bolt 4.0+ (the ROUTE message and `CALL
        # dbms.routing.getRoutingTable` are 4.0+ features). If we got
        # this far the answer is always true.
        def supports_multi_db?
          true
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
            Handler.new(@routing_tables[database] || RoutingTable.new(database: database))
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
        def ensure_routing_table_is_fresh(database, access_mode, bookmarks: nil)
          @refresh_lock.synchronize do
            table = @routing_tables[database]
            return table if table && table.fresh?(readonly: access_mode == :read)

            update_routing_table(database, bookmarks: bookmarks)
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
        def update_routing_table(database, bookmarks: nil)
          existing = @routing_tables[database]
          prefer_seed = existing.nil? || existing.initialized_without_writers

          errors = []
          routers_in_order(existing, prefer_seed: prefer_seed).each do |router|
            new_table = fetch_routing_table_from(router, database, bookmarks, errors)
            next unless new_table

            apply_routing_table(database, new_table)
            return @routing_tables[database]
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
          seed = seed_router
          existing_others = existing ? existing.routers.to_a - [seed] : []
          prefer_seed ? [seed, *existing_others] : [*existing_others, seed]
        end

        # The driver's URI host:port is the seed router. Multi-seed
        # discovery (via resolver / URI list) is a future slice; one
        # seed is enough to bootstrap most clusters.
        def seed_router
          ServerAddress.parse("#{@uri.host}:#{@uri.port || ServerAddress::DEFAULT_PORT}")
        end

        # Returns a new RoutingTable on success, nil on a per-router
        # failure. Connection-level failures additionally `deactivate`
        # the router; protocol-level failures (e.g. ClientException
        # while routing) just record the error so the caller tries the
        # next router.
        def fetch_routing_table_from(router, database, bookmarks, errors)
          pool = pool_for(router)
          conn = nil
          begin
            # pop is inside the begin block on purpose: open_connection
            # is the pool's create block and can raise ServiceUnavailable
            # (router unreachable). If that escaped the method,
            # update_routing_table's iteration over remaining routers
            # would stop on the first unreachable one.
            conn = pool.pop(timeout: acquisition_timeout_seconds)
            rt = conn.route(database: database, bookmarks: Array(bookmarks), routing_context: @routing_context)
            new_table = RoutingTable.from_response(symbolize(rt), database)

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

          code.start_with?('Neo.ClientError.Security.') &&
            code != 'Neo.ClientError.Security.AuthorizationExpired'
        end

        def apply_routing_table(database, new_table)
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
        # pool. `decrement_created` frees the slot in TimedStack so the
        # next pop can lazily build a fresh one.
        def discard(address, conn)
          conn.close rescue nil
          @refresh_lock.synchronize do
            @pools[address]&.decrement_created
          end
        end

        def pool_for(address)
          @refresh_lock.synchronize do
            @pools[address] ||= ConnectionPool::TimedStack.new(size: max_pool_size) do
              open_connection(address)
            end
          end
        end

        def open_connection(address)
          uri = "bolt://#{address}"
          # routing_context goes into the HELLO map so the cluster can
          # apply the configured policy / region (the same routing
          # context is sent to readers/writers too; non-router servers
          # just ignore it).
          opts = @options.merge(routing_context: @routing_context)
          Bolt::Connection.new(uri, @auth, opts).connect
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

        def acquisition_timeout_seconds
          @options[:connection_acquisition_timeout] || Driver::DEFAULT_ACQUISITION_TIMEOUT
        end

        def format_acquisition_timeout
          "#{(acquisition_timeout_seconds * 1000).to_i}ms"
        end
      end
    end
  end
end
