# frozen_string_literal: true

module Neo4j
  module Driver
    # Factory for the driver's default BookmarkManager. Mirrors
    # `org.neo4j.driver.BookmarkManagers#defaultManager` — but with
    # a Ruby keyword-arg surface instead of a config builder, matching
    # the JRuby flavour's ext shim (see lib/jruby/.../ext/bookmark_managers.rb).
    #
    # `initial_bookmarks`  — seed the manager with bookmarks the caller
    #                         already has (e.g. from a persisted store).
    # `bookmarks_supplier` — callable returning extra bookmarks to merge
    #                         into every `get_bookmarks` call (lets external
    #                         bookmark sources participate without being
    #                         folded into the manager's own state).
    # `bookmarks_consumer` — callable receiving the new bookmark snapshot
    #                         after every successful update (lets external
    #                         observers persist or forward bookmarks).
    module BookmarkManagers
      def self.default_manager(initial_bookmarks: nil, bookmarks_supplier: nil, bookmarks_consumer: nil)
        Internal::DefaultBookmarkManager.new(
          initial_bookmarks:,
          bookmarks_supplier:,
          bookmarks_consumer:
        )
      end
    end
  end
end
