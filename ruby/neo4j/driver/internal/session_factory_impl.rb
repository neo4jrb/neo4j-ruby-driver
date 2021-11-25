module Neo4j::Driver
  module Internal
    class SessionFactoryImpl
      attr_reader :connection_provider
      delegate :verify_connectivity, :close, to: :connection_provider

      def initialize(connection_provider, retry_logic, config)
        @connection_provider = connection_provider
        @leakedSessionsLoggingEnabled = config[:leaked_session_logging]
        @retry_logic = retry_logic
        @logging = config.java_config.logging
        @defaultFetchSize = config[:fetch_size]
      end

      def supports_multi_db?
        connection_provider.supports_multi_db
      end

      def new_instance(fetch_size: @defaultFetchSize, default_access_mode: org.neo4j.driver.AccessMode::WRITE, **config)
        bookmarkHolder = org.neo4j.driver.internal.DefaultBookmarkHolder.new(
          org.neo4j.driver.internal.InternalBookmark.from(config[:bookmarks]&.then { |bookmarks| java.util.ArrayList.new(Array(bookmarks)) }))
        create_session(parseDatabaseName(config), default_access_mode, bookmarkHolder, fetch_size, config[:impersonated_user], @logging)
      end

      private

      def parseDatabaseName(config)
        config[:database]&.then(&org.neo4j.driver.internal.DatabaseNameUtil.method(:database)) ||
          org.neo4j.driver.internal.DatabaseNameUtil.defaultDatabase
      end

      def create_session(databaseName, mode, bookmarkHolder, fetchSize, impersonated_user, logging)
        (@leakedSessionsLoggingEnabled ? org.neo4j.driver.internal.async.LeakLoggingNetworkSession : org.neo4j.driver.internal.async.NetworkSession)
          .new(@connection_provider, @retry_logic, databaseName, mode, bookmarkHolder, impersonated_user, fetchSize, logging)
      end
    end
  end
end
