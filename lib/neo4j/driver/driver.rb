# frozen_string_literal: true

require 'uri'

module Neo4j
  module Driver
    # Driver for connecting to Neo4j
    class Driver
      def initialize(uri, auth, options = {})
        @uri = uri
        @auth = auth
        @options = options
        @closed = false
        @connection_pool = []
      end

      def session(options = {}, &block)
        raise Exceptions::ClientException, 'Driver is closed' if @closed

        merged_options = @options.merge(options)
        session = Session.new(self, merged_options)

        if block_given?
          begin
            yield session
          ensure
            # Block form hands lifecycle to the driver, so close-time
            # failures from abandoned results (e.g. pending PULL that
            # would have errored) are treated as cancellations. Callers
            # who want to observe such errors should manage the session
            # explicitly and call #close themselves.
            begin
              session.close
            rescue Exceptions::Neo4jException
            end
          end
        else
          session
        end
      end

      def acquire_connection
        # Simple connection pooling - reuse closed connections or create new ones
        connection = @connection_pool.find { |conn| conn.closed? }

        if connection
          # Remove old connection and create new one
          @connection_pool.delete(connection)
        end

        # Create new connection
        connection = Bolt::Connection.new(@uri, @auth, @options)
        connection.connect
        @connection_pool << connection
        connection
      end

      def close
        return if @closed

        @connection_pool.each(&:close)
        @connection_pool.clear
        @closed = true
      end

      def verify_connectivity
        begin
          conn = acquire_connection
          # If we got here, connection was successful
          conn.close
          true
        rescue => e
          # Re-raise authentication errors appropriately
          if e.message.include?('Authentication failed')
            raise Exceptions::AuthenticationException, e.message
          else
            raise Exceptions::ServiceUnavailableException, "Failed to verify connectivity: #{e.message}"
          end
        end
      end

      def closed?
        @closed
      end
    end
  end
end
