module Neo4j::Driver
  module Internal
    class SessionFactoryImpl
      attr_reader :connection_provider
      delegate :verify_connectivity, :close, to: :connection_provider

      def initialize(connection_provider, retry_logic, config)
        @connection_provider = connection_provider
        @leaked_sessions_logging_enabled = config[:leaked_session_logging]
        @retry_logic = retry_logic
        @logger = config[:logger]
        @default_fetch_size = config[:fetch_size]
      end

      def new_instance(fetch_size: @default_fetch_size, default_access_mode: org.neo4j.driver.AccessMode::WRITE, **config)
        bookmark_holder = DefaultBookmarkHolder.new(InternalBookmark.from(config[:bookmarks]&.then(&method(:Array))))
        create_session(parse_database_name(config), default_access_mode, bookmark_holder, fetch_size, config[:impersonated_user])
      end

      def supports_multi_db?
        @connection_provider.supports_multi_db
      end

      private

      def parse_database_name(config)
        config[:database]&.then(&DatabaseNameUtil.method(:database)) || DatabaseNameUtil.default_database
      end

      def create_session(database_name, mode, bookmark_holder, fetch_size, impersonated_user)
        @logger.debug('called create_session')
        (@leaked_sessions_logging_enabled ? org.neo4j.driver.internal.async.LeakLoggingNetworkSession : Async::NetworkSession)
          .new(@connection_provider, @retry_logic, database_name, mode, bookmark_holder, impersonated_user, fetch_size, @logger)
      end
    end
  end
end
