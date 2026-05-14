module TestkitBackend
  module Requests
    # Stub; see NewBookmarkManager.
    class BookmarkManagerClose < Request
      def process
        delete(id)
        named_entity('BookmarkManager', id: id)
      end
    end
  end
end
