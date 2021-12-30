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
        database_name_future = context.database_name_future
        database_name_future.complete(DatabaseNameUtil::DEFAULT_DATABASE)
        acquire_connection.then_apply do |connection|
          Async::Connection::DirectConnection.new(connection,
                                                  Futures.join_now_or_else_throw(database_name_future,Async::ConnectionContext::PENDING_DATABASE_NAME_EXCEPTION_SUPPLIER),
                                                  context.mode, context.impersonated_user)
        end
      end

      def verify_connectivity
        acquire_connection.then_compose(Spi::Connection::release)
      end

      def supports_multi_db
        acquire_connection.then_compose do |conn|
          supports_multi_database = supports_multi_database(conn)
          conn.release.then_apply(-> (_ignored) { supports_multi_database })
        end
      end

      private

      # Used only for grabbing a connection with the server after hello message.
      # This connection cannot be directly used for running any queries as it is missing necessary connection context
      def acquire_connection
        @connection_pool.acquire(address)
      end
    end
  end
end
