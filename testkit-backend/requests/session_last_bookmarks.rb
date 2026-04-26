# frozen_string_literal: true

module TestkitBackend
  module Requests
    class SessionLastBookmarks < Data.define(:session_id)
      include Request

      def execute
        bookmarks = registry.fetch(session_id).last_bookmarks.to_a.map(&:value)
        Response::Bookmarks.new(bookmarks: bookmarks)
      end
    end
  end
end
