module Neo4j::Driver
  module Internal
    class DefaultBookmarkHolder
      attr_reader :bookmark

      def initialize(bookmark = InternalBookmark.empty)
        @bookmark = bookmark
      end

      def bookmark=(bookmark)
        @bookmark = bookmark if bookmark.present?
      end
    end
  end
end
