module Testkit::Backend::Messages
  module Requests
    class SessionLastBookmarks < Request
      def process
        named_entity('Bookmarks', bookmarks: to_object.to_set.to_a)
      end

      def to_object
        fetch(session_id).last_bookmark
      end
    end
  end
end