# frozen_string_literal: true

module Neo4j
  module Driver
    # Driver for connecting to Neo4j
    class Driver
      DEFAULT_MAX_POOL_SIZE = 100
      DEFAULT_ACQUISITION_TIMEOUT = 60

      def initialize(uri, auth, options = {})
        @uri = uri
        @auth = auth
        @options = options
        @closed = false
      end

      def session(options = {}, &block)
        raise Exceptions::ClientException, 'Driver is closed' if @closed

        merged_options = @options.merge(options)
        session = Session.new(self, merged_options)

        if block_given?
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
        else
          session
        end
      end

      def acquire_connection
        pool.pop(timeout: acquisition_timeout_seconds)
      rescue ::Timeout::Error
        raise Exceptions::ClientException,
              "Unable to acquire connection from the pool within configured maximum time of #{format_acquisition_timeout}"
      end

      def release_connection(connection)
        return unless connection

        pool.push(connection)
      end

      def close
        return if @closed

        @closed = true
        @pool&.shutdown { |conn| conn.close rescue nil }
      end

      def verify_connectivity
        conn = acquire_connection
        release_connection(conn)
        true
      rescue Exceptions::AuthenticationException
        raise
      rescue StandardError => e
        raise Exceptions::ServiceUnavailableException, "Failed to verify connectivity: #{e.message}"
      end

      # True iff the negotiated Bolt protocol supports multi-database
      # routing (Bolt 4.0+). Acquires a connection to ensure the handshake
      # has happened.
      def supports_multi_db?
        conn = acquire_connection
        conn.protocol.supports_multiple_databases?
      ensure
        release_connection(conn)
      end

      def closed?
        @closed
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
        @options[:max_connection_pool_size] || DEFAULT_MAX_POOL_SIZE
      end

      def acquisition_timeout_seconds
        @options[:connection_acquisition_timeout]&.to_f || DEFAULT_ACQUISITION_TIMEOUT
      end

      def format_acquisition_timeout
        millis = (acquisition_timeout_seconds * 1000).to_i
        "#{millis}ms"
      end
    end
  end
end
