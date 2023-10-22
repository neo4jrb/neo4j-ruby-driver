module Neo4j::Driver
  module Internal
    # A no-op {@link BookmarkManager} implementation.
    class NoOpBookmarkManager
      include BookmarkManagers

      def update_bookmarks(database, previous_bookmarks, new_bookmarks)
      end

      def bookmarks(database)
        []
      end

      def all_bookmarks
        []
      end

      def forget(database)
      end
    end
  end
end
