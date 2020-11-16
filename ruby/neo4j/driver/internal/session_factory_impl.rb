module Neo4j::Driver
  module Internal
    class SessionFactoryImpl
      attr_reader :connection_provider
      delegate :verify_connectivity, :close, :supports_multi_db?, to: :connection_provider

      def initialize(connection_provider, retryLogic, config)
        @connection_provider = connection_provider
        @leakedSessionsLoggingEnabled = config.logLeakedSessions
        @retryLogic = retryLogic
        @logging = config.logging
        @defaultFetchSize = config.fetchSize
      end

      def new_instance(fetch_size: @defaultFetchSize, bookmarks: nil, default_access_mode: org.neo4j.driver.AccessMode::WRITE, database: nil)
        bookmarkHolder = org.neo4j.driver.internal.DefaultBookmarkHolder.new(
          org.neo4j.driver.internal.InternalBookmark.from(bookmarks ? java.util.ArrayList.new(Array(bookmarks)) : nil))
        create_session(parseDatabaseName(database), default_access_mode, bookmarkHolder, fetch_size, @logging)
      end

      private

      def parseDatabaseName(database)
        database ?
          org.neo4j.driver.internal.DatabaseNameUtil.database(database)
          : org.neo4j.driver.internal.DatabaseNameUtil.defaultDatabase
      end

      def create_session(databaseName, mode, bookmarkHolder, fetchSize, logging)
        (@leakedSessionsLoggingEnabled ? org.neo4j.driver.internal.async.LeakLoggingNetworkSession : org.neo4j.driver.internal.async.NetworkSession)
          .new(@connection_provider, @retryLogic, databaseName, mode, bookmarkHolder, fetchSize, logging)
      end
    end
  end
end
