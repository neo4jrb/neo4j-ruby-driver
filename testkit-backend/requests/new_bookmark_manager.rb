module TestkitBackend
  module Requests
    # Stub: the Ruby driver doesn't advertise Feature:API:BookmarkManager.
    class NewBookmarkManager < Request
      def process
        reference('BookmarkManager')
      end

      def to_object
        Object.new
      end
    end
  end
end
