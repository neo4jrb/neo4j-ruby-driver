module TestkitBackend
  module Requests
    # Instantiates a driver-default BookmarkManager via
    # Neo4j::Driver::BookmarkManagers.default_manager. When the frontend
    # registers a supplier/consumer, the driver calls back into us; we relay
    # each call to the frontend as a BookmarksSupplierRequest /
    # BookmarksConsumerRequest and block for its *Completed reply — the same
    # synchronous backend->frontend pattern NewDriver uses for the resolver.
    class NewBookmarkManager < Request
      def process
        reference('BookmarkManager')
      end

      def to_object
        # The callbacks need the manager's testkit id, which is its object_id
        # (see ObjectCache.store) — known only once the object exists, so the
        # closures capture the `manager` local and read it lazily at call time.
        manager = nil
        manager = Neo4j::Driver::BookmarkManagers.default_manager(
          initial_bookmarks: initial_bookmarks&.map(&Neo4j::Driver::Bookmark.method(:from)),
          bookmarks_supplier: (-> { supply(manager.object_id) } if bookmarks_supplier_registered),
          bookmarks_consumer: (->(bookmarks) { consume(manager.object_id, bookmarks) } if bookmarks_consumer_registered)
        )
      end

      private

      def supply(bookmark_manager_id)
        @command_processor.process_response(
          named_entity('BookmarksSupplierRequest', id: bookmark_manager_id, bookmark_manager_id: bookmark_manager_id))
        bookmarks = @command_processor.process(blocking: true).bookmarks || []
        java.util.HashSet.new(bookmarks.map(&Neo4j::Driver::Bookmark.method(:from)))
      end

      def consume(bookmark_manager_id, bookmarks)
        @command_processor.process_response(
          named_entity('BookmarksConsumerRequest', id: bookmark_manager_id, bookmark_manager_id: bookmark_manager_id,
                       bookmarks: bookmarks.map(&:value)))
        @command_processor.process(blocking: true)
        nil
      end
    end
  end
end
