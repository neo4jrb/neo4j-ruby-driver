module Neo4j::Driver
  module Internal
    class ReadOnlyBookmarkHolder
      attr_reader :bookmark

      def initialize(bookmark = InternalBookmark.empty)
        @bookmark = bookmark
      end

      def bookmark=(_value) end
    end
  end
end
