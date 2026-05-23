# frozen_string_literal: true

module Neo4j
  module Driver
    # Public contract for cross-session bookmark propagation. Two
    # methods — `get_bookmarks` for what a session should send in
    # BEGIN, and `update_bookmarks(prev, new)` for what to fold in
    # after a successful commit. Mirrors
    # `org.neo4j.driver.BookmarkManager`.
    #
    # Most callers don't subclass — use
    # `BookmarkManagers.default_manager(...)` to get a thread-safe
    # in-memory implementation with optional supplier / consumer
    # callbacks for integration with external bookmark stores.
    class BookmarkManager
      def get_bookmarks
        raise NotImplementedError, "#{self.class} must implement get_bookmarks"
      end

      def update_bookmarks(_previous_bookmarks, _new_bookmarks)
        raise NotImplementedError, "#{self.class} must implement update_bookmarks"
      end
    end
  end
end
