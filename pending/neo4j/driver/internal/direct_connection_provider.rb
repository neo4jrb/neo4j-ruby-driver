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
        database_name_future.fulfill(DatabaseNameUtil::DEFAULT_DATABASE)
        puts "before private_acquire_connection"
        private_acquire_connection.then do |connection|
          puts "before Async::Connection::DirectConnection.new"
          Async::Connection::DirectConnection.new(
            connection,
            Util::Futures.join_now_or_else_throw(database_name_future,
                                                 &Async::ConnectionContext::PENDING_DATABASE_NAME_EXCEPTION_SUPPLIER).tap { |it| puts "database_name=#{it}" },
            context.mode, context.impersonated_user)
        end.tap { puts "exiting DirectConnectionProvider#acquire_connection" }
      end

      def verify_connectivity
        private_acquire_connection.then_flat(&:release)
      end

      def supports_multi_db?
        private_acquire_connection.then_flat do |conn|
          supports_multi_database = supports_multi_database?(conn)
          conn.release.then { supports_multi_database }
        end
      end

      private

      # Used only for grabbing a connection with the server after hello message.
      # This connection cannot be directly used for running any queries as it is missing necessary connection context
      def private_acquire_connection
        puts "entering DirectConnectionProvider#private_acquire_connection"
        @connection_pool.acquire(@address).tap { puts "exiting DirectConnectionProvider#private_acquire_connection" }
      end
    end
  end
end
