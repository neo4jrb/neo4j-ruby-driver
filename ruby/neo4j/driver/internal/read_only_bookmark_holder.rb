module Neo4j::Driver
  module Internal
    class ReadOnlyBookmarkHolder
      attr_reader :bookmarks

      def initialize(bookmarks = Set[])
        @bookmarks = bookmarks
      end

      def bookmarks=(_value) end
    end
  end
end
