module Neo4j
  module Driver
    # The session configurations used to configure a session.
    class SessionConfig < Hash
      attr_reader :bookmarks, :default_access_mode, :database, :fetch_size, :impersonated_user
      def initialize(**config)
        @bookmarks = config.bookmarks
        @default_access_mode = config.default_access_mode
        @database = config.database
        @fetch_size = config.fetch_size
        @impersonated_user = config.impersonated_user
      end
    end
  end
end
