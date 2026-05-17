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

      def initialize(uri, auth, options = {})
        @uri = URI(uri)
        @options = options
        @closed = false
        @connection_provider = build_connection_provider(@uri, auth)
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
      rescue Exceptions::AuthenticationException
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
      # `config` mirrors what testkit's ExecuteQuery sends:
      #   :database (str), :routing ('w' | 'r'), :impersonatedUser,
      #   :bookmarkManagerId, :txMeta, :timeout, :authorizationToken.
      # Honours :database and :routing today; ignores the rest until the
      # corresponding driver features land (impersonation, bookmark
      # manager, per-session auth, etc.).
      def execute_query(cypher, params = {}, config = {})
        routing = (config[:routing] || config['routing'] || 'w').to_s
        database = config[:database] || config['database']

        session_opts = {
          database: database,
          default_access_mode: routing == 'r' ? AccessMode::READ : AccessMode::WRITE
        }.compact

        keys = nil
        records = nil
        summary = nil

        session(session_opts) do |s|
          method = routing == 'r' ? :execute_read : :execute_write
          s.send(method) do |tx|
            result = tx.run(cypher, **params)
            records = result.to_a
            keys = result.keys
            summary = result.consume
          end
        end

        EagerResult.new(keys, records, summary)
      end

      # Verify that the supplied auth token would succeed against the
      # server, without disturbing the existing connection state.
      #
      # NOT YET IMPLEMENTED: needs a "test-only" connection probe that
      # runs HELLO/LOGON with the supplied token, classifies the outcome,
      # and reports back. See VerifyAuthentication in the testkit-backend
      # for the expected response shape.
      def verify_authentication(_auth_token)
        raise NotImplementedError,
              'Driver#verify_authentication: HELLO/LOGON probe not yet implemented'
      end

      # Server-level info (address, agent, protocol version) for the
      # current driver — useful for tests that want the negotiated
      # version without running a query.
      #
      # NOT YET IMPLEMENTED: a clean port acquires any connection,
      # reads .address / .protocol.agent / .protocol.version_string,
      # releases, and returns a struct.
      def server_info
        raise NotImplementedError,
              'Driver#server_info: not yet exposed (probe-and-return needed)'
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

      # Internal — mirrors Java's Driver#getSessionFactory() so testkit
      # backend handlers (GetRoutingTable, ForcedRoutingTableUpdate)
      # can use the same chain on both JRuby and MRI:
      #   driver.session_factory.connection_provider
      #         .routing_table_registry.routing_table_handler(db)
      #         .routing_table
      # MRI has no real SessionFactory layer — Driver plays both roles.
      def session_factory = self

      attr_reader :connection_provider

      private

      def build_connection_provider(uri, auth)
        klass = uri.scheme.start_with?('neo4j') ? Routing::LoadBalancer : Direct::ConnectionProvider
        klass.new(uri, auth, @options)
      end
    end
  end
end
