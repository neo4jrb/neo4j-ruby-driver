module Neo4j::Driver
  module Internal

    # @since 2.0
    class DefaultBookmarkHolder
      attr_accessor :bookmark

      def initialize(bookmark = InternalBookmark.empty)
        @bookmark = bookmark
      end
    end
  end
end
