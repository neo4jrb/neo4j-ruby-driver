module Testkit::Backend::Messages
  module Requests
    class SessionLastBookmarks < Request
      def process
        named_entity('Bookmarks', bookmarks: to_object.map(&:value))
      end

      def to_object
        fetch(session_id).last_bookmarks
      end
    end
  end
end