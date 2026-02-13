module Neo4j::Driver
  module Internal
    class InternalBookmark < String
      include Bookmark
      alias value itself

      def to_s = "Bookmark{value=#{super}}"
    end
  end
end
