module Testkit::Backend::Messages
  module Requests
    class BookmarksSupplierCompleted < Request
      def process
        bookmarks = fetch(request_id).bookmarks
        named_entity('BookmarksSupplierRequest', id: bookmarks.id, bookmarkManagerId: bookmarks.bookmark_manager_id, database: bookmarks.database)
      end
    end
  end
end
