module Neo4j::Driver
  module Internal
    class InternalBookmark < String
      include Bookmark

      def to_s = "Bookmark{value=#{super}}"
    end
  end
end
