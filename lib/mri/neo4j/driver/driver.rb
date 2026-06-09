# frozen_string_literal: true

module Neo4j
  module Driver
    # Driver for connecting to Neo4j.
    #
    # Holds a single ConnectionProvider (Direct for `bolt://`, Routing for
    # `neo4j://`) chosen at construction. All connection work delegates to
    # the provider — no scheme branching here.
    class Driver
      DEFAULT_MAX_POOL_SIZE = 100
      DEFAULT_ACQUISITION_TIMEOUT = 60

      # URI schemes that imply transport encryption.
      ENCRYPTED_SCHEMES = %w[bolt+s bolt+ssc neo4j+s neo4j+ssc].freeze

      def initialize(uri, auth_manager, options = {})
        @uri = URI(uri)
        @options = options
        @closed = false
        @connection_provider = build_connection_provider(@uri, auth_manager)
      end

      def session(**options)
        raise Exceptions::ClientException, 'Driver is closed' if @closed

        merged_options = @options.merge(options)
        session = Session.new(@connection_provider, merged_options)

        return session unless block_given?

        begin
          result = yield session
        rescue => block_error
          # Block raised; preserve as primary, attach close-time failures
          # as suppressed (Java try-with-resources semantics).
          begin
            session.close
          rescue Exceptions::Neo4jException => close_error
            block_error.add_suppressed(close_error) if block_error.respond_to?(:add_suppressed)
          end
          raise
        else
          # Block exited cleanly. Any close-time error here comes from
          # draining a result the user never iterated — Java semantics
          # treat that as cancellation, not a real failure.
          begin
            session.close
          rescue Exceptions::Neo4jException
          end
          result
        end
      end

      def close
        return if @closed

        @closed = true
        @connection_provider.close
      end

      def verify_connectivity
        @connection_provider.verify_connectivity
      rescue Exceptions::Neo4jException
        # Propagate driver exceptions (auth/security/client/service-
        # unavailable) as-is, like Java — wrapping them would hide the
        # type and message callers assert on. Only unexpected non-driver
        # errors get the contextual wrapper.
        raise
      rescue StandardError => e
        raise Exceptions::ServiceUnavailableException, "Failed to verify connectivity: #{e.message}"
      end

      def supports_multi_db?
        @connection_provider.supports_multi_db?
      end

      def closed?
        @closed
      end

      # True iff the driver was constructed to enforce transport encryption
      # — either via a +s/+ssc URI scheme or an explicit `encrypted: true`
      # option. Mirrors Java's Driver.isEncrypted().
      def encrypted?
        ENCRYPTED_SCHEMES.include?(@uri.scheme) || @options[:encrypted] == true
      end

      # Whether the connected server supports per-session re-authentication
      # (Bolt 5.1+). Probes a connection to read the negotiated protocol's
      # capability flag. Today our handshake only advertises Bolt 4.4, so
      # this returns false until the Bolt 5.x HELLO/LOGON work lands.
      def supports_session_auth?
        connection = @connection_provider.acquire(access_mode: :read)
        connection.protocol.supports_re_auth?
      ensure
        @connection_provider.release(connection) if connection
      end

      # Run a query in a managed transaction and return EagerResult
      # (keys, materialised records, summary). Convenience for "I just
      # want results, don't make me build a session".
      #
      # Signature: `(query, params = {}, config = {})`. Same shape
      # Session#run uses.
      #
      # `config` keys (snake_case):
      #   :database            — string, the database to target.
      #   :routing             — RoutingControl::READ / ::WRITE.
      #   :bookmark_manager    — BookmarkManager for cross-session
      #                          causal consistency. Pass `nil`
      #                          explicitly to disable; omit to use
      #                          the driver default.
      #   :impersonated_user   — server runs the query as if this user
      #                          had issued it (Bolt 4.4+, requires
      #                          impersonator privileges).
      #   :metadata            — map echoed back in summary; used by
      #                          query-log / monitoring tooling.
      #   :timeout             — seconds (or ActiveSupport::Duration);
      #                          server-side transaction timeout.
      #   :auth_token          — accepted but not yet honoured —
      #                          per-call auth is its own slice
      #                          (Bolt 5.1+ LOGOFF/LOGON).
      def execute_query(cypher, params = {}, config = {})
        routing = config[:routing] || RoutingControl::WRITE

        # `bookmark_manager: nil` is meaningful (explicitly disables the
        # manager) and differs from omitting the key, so it's added
        # conditionally rather than via .compact. `:database` /
        # `:impersonated_user` keep .compact semantics (nil == omitted).
        session_opts = {
          database: config[:database],
          default_access_mode: routing,
          impersonated_user: config[:impersonated_user]
        }.compact
        session_opts[:bookmark_manager] = config[:bookmark_manager] if config.key?(:bookmark_manager)

        # Forwarded to the managed-tx call below — the BEGIN extras
        # honour metadata/timeout per-tx, not session-wide.
        tx_kwargs = {
          metadata: config[:metadata],
          timeout: config[:timeout]
        }.compact

        keys = nil
        records = nil
        summary = nil

        session(**session_opts) do |s|
          method = routing == RoutingControl::READ ? :execute_read : :execute_write
          s.send(method, **tx_kwargs) do |tx|
            result = tx.run(cypher, **params)
            records = result.to_a
            keys = result.keys
            summary = result.consume
          end
        end

        EagerResult.new(keys, records, summary)
      end

      # Verify that the supplied auth token would succeed against the
      # server, without disturbing the existing connection state. Opens
      # a one-shot connection with the token, discards it after
      # HELLO/LOGON. Returns true on SUCCESS, false on
      # AuthenticationException. Any other exception (transport
      # failure, TLS rejection, server unreachable, …) propagates so
      # the caller can distinguish "credentials rejected" from
      # "couldn't even ask".
      #
      # Mirrors Java's `Driver.verifyAuthentication(AuthToken)`
      # signature — the token is required; pass AuthTokens.none if
      # you want the unauthenticated probe.
      def verify_authentication(auth_token)
        probe = Bolt::Connection.new(@uri, auth_token, @options)
        probe.connect
        true
      rescue Exceptions::AuthenticationException
        false
      ensure
        probe&.close
      end

      # Per-server-address pool metrics: how many connections currently
      # in use vs. idle. Test-only API.
      #
      # NOT YET IMPLEMENTED: pool metrics infrastructure doesn't exist.
      # See get_connection_pool_metrics.rb in the testkit-backend for
      # the required driver-side pieces.
      def pool_metrics(_address)
        raise NotImplementedError,
              'Driver#pool_metrics: per-address pool metrics not yet implemented'
      end

      # Routing table for `database` (testkit GetRoutingTable). Returns the
      # routing table from the load balancer; testkit reads routers/writers/
      # readers + ttl off it without knowing this internal path.
      def routing_table(database)
        connection_provider.routing_table_registry.routing_table_handler(database).routing_table
      end

      # Force a routing-table refresh (testkit ForcedRoutingTableUpdate).
      def routing_table_refresh(database, bookmarks)
        connection_provider.routing_table_registry.refresh(database, bookmarks)
      end

      attr_reader :connection_provider

      private

      def build_connection_provider(uri, auth_manager)
        klass = uri.scheme.start_with?('neo4j') ? Routing::LoadBalancer : Direct::ConnectionProvider
        klass.new(uri, auth_manager, @options)
      end
    end
  end
end
