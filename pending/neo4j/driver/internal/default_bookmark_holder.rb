module Neo4j::Driver
  module Internal

    # @since 2.0
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
