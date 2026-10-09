# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Returns the referenced session's last bookmarks.
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
