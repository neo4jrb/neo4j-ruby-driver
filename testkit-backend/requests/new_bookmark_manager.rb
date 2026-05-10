# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Creates a bookmark manager. Tests use it to share bookmarks across
    # sessions (e.g. cluster routing scenarios). Stores a placeholder
    # carrying the testkit-supplied initial bookmarks and supplier/consumer
    # registration flags, so debugging and a future close handler can
    # see what testkit asked for.
    #
    # DRIVER GAP: needs a BookmarkManager interface in Neo4j::Driver.
    # The Java reference is org.neo4j.driver.BookmarkManager. Required
    # pieces:
    #   - Driver / Session / TransactionConfig accept a :bookmark_manager
    #     option
    #   - Session#run reads the manager's bookmarks before each query and
    #     pushes the new bookmark back after a successful commit
    #   - When supplier/consumer callbacks are registered, the Ruby Procs
    #     round-trip through the testkit channel (Response::Bookmarks*Request
    #     → Request::Bookmarks*Completed) — analogous to the resolver flow
    #     in NewDriver.
    class NewBookmarkManager < Data.define(
      :initial_bookmarks,
      :bookmarks_supplier_registered,
      :bookmarks_consumer_registered
    )
      include Request

      def execute
        placeholder = {
          type: :bookmark_manager,
          initial_bookmarks: initial_bookmarks,
          supplier_registered: bookmarks_supplier_registered,
          consumer_registered: bookmarks_consumer_registered
        }
        Response::BookmarkManager.new(id: registry.store(placeholder, prefix: 'bmmgr'))
      end
    end
  end
end
