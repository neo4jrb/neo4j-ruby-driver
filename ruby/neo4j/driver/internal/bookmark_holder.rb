module Neo4j::Driver
  module Internal
    class BookmarkHolder
      NO_OP = DefaultBookmarkHolder.new
    end
  end
end
