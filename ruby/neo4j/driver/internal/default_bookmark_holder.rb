module Neo4j::Driver
  module Internal
    class DefaultBookmarkHolder < ReadOnlyBookmarkHolder
      def bookmarks=(bookmarks)
        @bookmarks = bookmarks
      end
    end
  end
end
