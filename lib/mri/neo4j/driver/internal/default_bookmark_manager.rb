# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Thread-safe in-memory implementation behind
      # `BookmarkManagers.default_manager`. Internal because callers
      # code against the duck type (`bookmarks` + `update_bookmarks`)
      # and shouldn't depend on this class name.
      #
      # `bookmarks_supplier` runs on every `bookmarks` call so external
      # state (e.g. bookmarks persisted by another node in a cluster of
      # app servers) is folded into what we send on BEGIN.
      # `bookmarks_consumer` runs on every successful `update_bookmarks`
      # so external listeners can react.
      class DefaultBookmarkManager
        def initialize(initial_bookmarks: nil, bookmarks_supplier: nil, bookmarks_consumer: nil)
          @bookmarks = normalize(initial_bookmarks)
          @supplier = bookmarks_supplier
          @consumer = bookmarks_consumer
          @lock = Mutex.new
        end

        def bookmarks
          @lock.synchronize { @bookmarks.dup } | normalize(@supplier&.call)
        end

        # Java's BookmarkManagerImpl semantics: drop everything in
        # `previous` (set-difference is a no-op for entries we don't
        # have, so callers can pass the full "what I sent on BEGIN"
        # snapshot — including the session's own bookmarks — without
        # special-casing), then add the new ones from the commit
        # response. Consumer sees the post-update set.
        def update_bookmarks(previous, new)
          prev_set = normalize(previous)
          new_set = normalize(new)
          updated_snapshot = nil
          @lock.synchronize do
            @bookmarks -= prev_set
            @bookmarks |= new_set
            updated_snapshot = @bookmarks.dup
          end
          @consumer&.call(updated_snapshot)
        end

        private

        def normalize(bookmarks)
          Set.new(Array(bookmarks).map(&Bookmark.method(:from)))
        end
      end
    end
  end
end
