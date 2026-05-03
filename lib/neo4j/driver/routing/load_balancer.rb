# frozen_string_literal: true

module Neo4j
  module Driver
    module Routing
      # Routing-aware connection pooling.
      #
      # Replaces Driver's single TimedStack with one pool per server address,
      # plus an in-memory routing table cache (keyed by database). On
      # acquire(access_mode:), picks a server from the appropriate role
      # bucket (round-robin), opens/checkout from that server's pool, and
      # falls through to the next server on connection failure.
      #
      # Slice 1 scope: happy-path verify_connectivity + session.run for one
      # database. No leader-change retry, no transient retry, no per-database
      # cache eviction. Those land in subsequent slices.
      class LoadBalancer
        ROUTING_CONTEXT_RESERVED_KEYS = %w[address].freeze

        def initialize(uri, auth, options = {})
          @uri = uri
          @auth = auth
          @options = options
          @routing_context = parse_routing_context(uri)
          @pools = {}                      # ServerAddress => ConnectionPool::TimedStack
          @routing_tables = {}             # database (str or nil) => RoutingTable
          @cursor = Hash.new(0)            # round-robin per (database, role)
          # Monitor (reentrant) because ensure_routing_table holds the lock
          # while it goes through pool_for, which also locks.
          @mutex = Monitor.new
        end

        # Open (or pop) a connection appropriate for `access_mode` against
        # `database` (nil = home db). Tries each server in role order until
        # one succeeds; raises if none do.
        def acquire(access_mode: :write, database: nil)
          table = ensure_routing_table(database)
          servers = table.servers_for(access_mode)
          raise Exceptions::ServiceUnavailableException,
                "No #{access_mode} servers available in routing table" if servers.empty?

          try_servers(servers, database, access_mode)
        end

        def release(connection)
          pool = @pools[ServerAddress.parse(connection.address)]
          pool&.push(connection)
        end

        # Routing-aware verify_connectivity: fetch a fresh routing table,
        # then probe *any* reader to confirm the cluster is reachable.
        def verify_connectivity
          # Force a fresh fetch — verify_connectivity is a probe, not a hit
          # against cached state. Matches the Java driver's behaviour and the
          # testkit `test_routing_fetches_home_db` expectation.
          @mutex.synchronize { @routing_tables.delete(nil) }
          conn = acquire(access_mode: :read)
          # RESET ensures the borrowed connection is in a known-clean state
          # for the probe and matches what testkit's `test_routing_from_pool`
          # asserts (one RESET per verify_connectivity).
          conn.reset!
          release(conn)
        end

        # Routing requires Bolt 4.0+ (the ROUTE message and `CALL dbms.routing.
        # getRoutingTable` are 4.0+ features). If we got this far the answer
        # is always true.
        def supports_multi_db?
          true
        end

        def close
          @mutex.synchronize do
            @pools.each_value { |pool| pool.shutdown { |conn| conn.close rescue nil } }
            @pools.clear
            @routing_tables.clear
          end
        end

        private

        def parse_routing_context(uri)
          return {} if uri.query.nil? || uri.query.empty?

          URI.decode_www_form(uri.query).each_with_object({}) do |(k, v), acc|
            raise ArgumentError, "Routing context key '#{k}' is reserved" if ROUTING_CONTEXT_RESERVED_KEYS.include?(k)

            acc[k.to_sym] = v
          end.tap { |ctx| ctx[:address] = "#{uri.host}:#{uri.port || ServerAddress::DEFAULT_PORT}" }
        end

        def ensure_routing_table(database)
          @mutex.synchronize do
            cached = @routing_tables[database]
            return cached if cached && !cached.expired?

            @routing_tables[database] = fetch_routing_table(database)
          end
        end

        def fetch_routing_table(database)
          last_error = nil
          initial_routers.each do |address|
            pool = pool_for(address)
            router_conn = pool.pop(timeout: acquisition_timeout_seconds)
            begin
              rt = router_conn.route(
                database: database, bookmarks: [], routing_context: @routing_context
              )
              return RoutingTable.from_response(symbolize(rt), database)
            ensure
              pool.push(router_conn)
            end
          rescue Exceptions::ServiceUnavailableException, ::Timeout::Error => e
            last_error = e
          end

          raise last_error || Exceptions::ServiceUnavailableException.new('No routers available')
        end

        # The driver's URI host:port is the seed router on first call. After
        # routing tables exist they may name additional routers; not yet used
        # in slice 1.
        def initial_routers
          [ServerAddress.parse("#{@uri.host}:#{@uri.port || ServerAddress::DEFAULT_PORT}")]
        end

        def try_servers(servers, database, access_mode)
          last_error = nil
          servers.size.times do
            address = next_server(servers, database, access_mode)
            pool = pool_for(address)
            begin
              return pool.pop(timeout: acquisition_timeout_seconds)
            rescue Exceptions::ServiceUnavailableException, ::Timeout::Error => e
              last_error = e
            end
          end

          raise last_error || Exceptions::ServiceUnavailableException.new(
            "All #{access_mode} servers unreachable"
          )
        end

        def next_server(servers, database, access_mode)
          key = [database, access_mode]
          server = servers[@cursor[key] % servers.size]
          @cursor[key] += 1
          server
        end

        def pool_for(address)
          @mutex.synchronize do
            @pools[address] ||= ConnectionPool::TimedStack.new(size: max_pool_size) do
              open_connection(address)
            end
          end
        end

        def open_connection(address)
          uri = "bolt://#{address}"
          Bolt::Connection.new(uri, @auth, @options).connect
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
      end
    end
  end
end
