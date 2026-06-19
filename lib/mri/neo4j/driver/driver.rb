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

      # The ConnectionProvider is assembled by the DriverFactory (which wires
      # in non-public hooks like the domain-name resolver), so the Driver
      # itself never sees those extension points — it just uses the provider.
      def initialize(uri, options, connection_provider)
        @uri = URI(uri)
        @options = options
        @closed = false
        @connection_provider = connection_provider
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
      # — either via a +s/+ssc URI scheme or an explicit `encryption: true`
      # option. Mirrors Java's Driver.isEncrypted().
      def encrypted?
        ENCRYPTED_SCHEMES.include?(@uri.scheme) || @options[:encryption] == true
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
      # server, without disturbing the existing connection state. Returns
      # true when the credentials are accepted, false when the server
      # rejects them (see VERIFY_AUTH_NEGATIVE_CODES). Any other error
      # (transport failure, TLS rejection, server unreachable, a security
      # code outside the negative set) propagates so the caller can
      # distinguish "credentials rejected" from "couldn't even ask".
      #
      # Mirrors Java's `Driver.verifyAuthentication(AuthToken)` — the token
      # is required; pass AuthTokens.none for the unauthenticated probe.

      # Security failure codes that mean "these credentials are not valid"
      # (verify_authentication returns false). Every other security error —
      # AuthorizationExpired, an unknown Security.* code, a rate-limit — is a
      # condition the caller must see, so it propagates. Mirrors Java's
      # verifyAuthentication NEGATIVE/PROPAGATE split.
      VERIFY_AUTH_NEGATIVE_CODES = %w[
        Neo.ClientError.Security.Unauthorized
        Neo.ClientError.Security.CredentialsExpired
        Neo.ClientError.Security.Forbidden
        Neo.ClientError.Security.TokenExpired
      ].freeze

      def verify_authentication(auth_token)
        # Acquire a read connection AS the supplied identity, routing through
        # `system` exactly like Java's verifyAuthentication: for neo4j:// this
        # discovers (ROUTE on system) then reaches a reader; for bolt:// it
        # uses the single server. We then force a LOGON with the token: a clean
        # response means the credentials are good. The connection is one-shot —
        # discarded, never pooled under the probe identity.
        connection = @connection_provider.acquire(
          access_mode: AccessMode::READ, database: 'system', auth: auth_token
        )
        begin
          # Force a fresh LOGON even when the pooled connection already holds
          # this identity (warm verify, or verifying the driver's own token):
          # verification has to actually round-trip the credentials to the
          # server, not trust a cached auth state. On a freshly built
          # connection this is a redundant re-auth the scripts tolerate; on a
          # reused one it's the whole point.
          connection.authenticate(auth_token, force: true)
        ensure
          connection.discard_on_release = true
          @connection_provider.release(connection)
        end
        true
      rescue Exceptions::SecurityException => e
        raise unless VERIFY_AUTH_NEGATIVE_CODES.include?(e.code)

        false
      end

      # Driver metrics. Today this only surfaces per-address connection-pool
      # occupancy (in-use / idle), which is all testkit's
      # GetConnectionPoolMetrics consumes; the counts come from the
      # ConnectionProvider, which owns the pools.
      def metrics
        Internal::Metrics.new(@connection_provider)
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
    end
  end
end
