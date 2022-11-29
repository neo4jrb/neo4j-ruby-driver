module Testkit::Backend::Messages
  module Requests
    class TestkitBookmarksConsumer
      def accept(database, bookmarks)
        fetch(request_id).bookmarks(id: id, bookmark_manager_id: bookmark_manager_id, database: database)
      end
    end
  end
end
