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
        def initialize(uri, auth, options = {})
          @uri = uri
          @auth = auth
          @options = options
        end

        def acquire(access_mode: nil, database: nil, bookmarks: nil)
          # See Routing::LoadBalancer#acquire for the rationale.
          raise Exceptions::IllegalStateException, 'Driver is closed' if @closed

          pool.pop(timeout: acquisition_timeout_seconds)
        rescue ::Timeout::Error
          raise Exceptions::ClientException,
                "Unable to acquire connection from the pool within configured maximum time of #{format_acquisition_timeout}"
        end

        def release(connection)
          pool.push(connection) if connection
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

        # TimedStack is connection_pool's underlying primitive. Unlike
        # ConnectionPool#checkout it does NOT cache per-thread, which is what
        # we need: each Session in the same thread must hold its own
        # connection (they can't share a server-side transaction state).
        def pool
          @pool ||= ConnectionPool::TimedStack.new(size: max_pool_size) do
            Bolt::Connection.new(@uri, @auth, @options).connect
          end
        end

        def max_pool_size
          @options[:max_connection_pool_size] || Driver::DEFAULT_MAX_POOL_SIZE
        end

        def acquisition_timeout_seconds
          @options[:connection_acquisition_timeout]&.to_f || Driver::DEFAULT_ACQUISITION_TIMEOUT
        end

        def format_acquisition_timeout
          "#{(acquisition_timeout_seconds * 1000).to_i}ms"
        end
      end
    end
  end
end
