# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Thread-safe in-memory BookmarkManager — the implementation
      # returned by `BookmarkManagers.default_manager`. Internal
      # because callers code against the `BookmarkManager` public
      # contract and shouldn't depend on this class name.
      #
      # `bookmarks_supplier` runs on every `get_bookmarks` call so
      # external state (e.g. bookmarks persisted by another node in
      # a cluster of app servers) is folded into what we send on
      # BEGIN. `bookmarks_consumer` runs on every successful
      # `update_bookmarks` so external listeners can react.
      class DefaultBookmarkManager < BookmarkManager
        def initialize(initial_bookmarks: nil, bookmarks_supplier: nil, bookmarks_consumer: nil)
          @bookmarks = Set.new(Array(initial_bookmarks).map(&Bookmark.method(:from)))
          @supplier = bookmarks_supplier
          @consumer = bookmarks_consumer
          @lock = Mutex.new
        end

        def get_bookmarks
          snapshot = @lock.synchronize { @bookmarks.dup }
          snapshot |= Set.new(Array(@supplier.call).map(&Bookmark.method(:from))) if @supplier
          snapshot
        end

        # Java's BookmarkManagerImpl semantics: drop everything in
        # `previous_bookmarks` (set-difference is a no-op for entries
        # we don't have, so it's safe for callers to pass the full
        # "what I sent on BEGIN" snapshot — including the session's
        # own bookmarks), then add the new ones from the commit
        # response. Consumer sees the post-update set.
        def update_bookmarks(previous_bookmarks, new_bookmarks)
          previous = normalise(previous_bookmarks)
          new = normalise(new_bookmarks)
          updated_snapshot = nil
          @lock.synchronize do
            @bookmarks -= previous
            @bookmarks |= new
            updated_snapshot = @bookmarks.dup
          end
          @consumer&.call(updated_snapshot)
        end

        private

        def normalise(bookmarks)
          Set.new(Array(bookmarks).map(&Bookmark.method(:from)))
        end
      end
    end
  end
end
