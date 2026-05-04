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

      def initialize(uri, auth, options = {})
        @options = options
        @closed = false
        @connection_provider = build_connection_provider(URI(uri), auth)
      end

      def session(options = {}, &block)
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

      private

      def build_connection_provider(uri, auth)
        klass = uri.scheme.start_with?('neo4j') ? Routing::LoadBalancer : Direct::ConnectionProvider
        klass.new(uri, auth, @options)
      end
    end
  end
end
