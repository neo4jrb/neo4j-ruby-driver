module Neo4j::Driver
  module Internal
    class BookmarkHolder
      NO_OP = Class.new(DefaultBookmarkHolder) do
        def bookmark=(_value) end
      end.new
    end
  end
end
