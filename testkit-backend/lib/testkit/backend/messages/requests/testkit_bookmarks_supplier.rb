module Testkit::Backend::Messages
  module Requests
    class TestkitBookmarksSupplier
      def bookmarks_from_testkit(database)
        fetch(request_id).bookmarks(id: id, bookmark_manager_id: bookmark_manager_id, database: database)
      end
    end
  end
end
