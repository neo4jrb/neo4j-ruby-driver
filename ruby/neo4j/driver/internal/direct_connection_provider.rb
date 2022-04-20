module Neo4j::Driver
  module Internal
    class DirectConnectionProvider
      attr_reader :address

      def initialize(address, connection_pool)
        @address = address
        @connection_pool = connection_pool
      end

      delegate :close, to: :@connection_pool

      def acquire_connection(context)
        database_name = context.database_name || DatabaseNameUtil::DEFAULT_DATABASE
        Async::Connection::DirectConnection.new(private_acquire_connection, database_name, context.mode,
                                                context.impersonated_user)
      end

      def verify_connectivity
        private_acquire_connection&.release
      end

      def supports_multi_db?
        private_acquire_connection.then do |conn|
          supports_multi_database?(conn)
        ensure
          conn.release
        end
      end

      private

      # Used only for grabbing a connection with the server after hello message.
      # This connection cannot be directly used for running any queries as it is missing necessary connection context
      def private_acquire_connection
        @connection_pool.acquire(@address)
      end
    end
  end
end
