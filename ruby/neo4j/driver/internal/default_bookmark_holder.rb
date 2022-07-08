module Neo4j::Driver
  module Internal
    class DefaultBookmarkHolder < ReadOnlyBookmarkHolder
      def bookmark=(bookmark)
        @bookmark = bookmark if bookmark.present?
      end
    end
  end
end
