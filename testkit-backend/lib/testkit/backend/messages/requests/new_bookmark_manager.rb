module Testkit::Backend::Messages
  module Requests
    class NewBookmarkManager < Request
      def process
        reference('NewBookmarkManager')
      end

      def to_object
        fetch(id).bookmarks(initial_bookmarks: initial_bookmarks,
          bookmarks_supplier_registered: bookmarks_supplier_registered,
          bookmarks_consumer_registered:bookmarks_consumer_registered)
      end
    end
  end
end
