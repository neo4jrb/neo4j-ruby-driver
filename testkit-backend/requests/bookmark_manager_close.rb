# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Tear down a bookmark manager handle. Idempotent — testkit may close
    # twice in some cleanup paths.
    class BookmarkManagerClose < Data.define(:id)
      include Request

      def execute
        registry.delete(id)
        Response::BookmarkManager.new(id: id)
      end
    end
  end
end
