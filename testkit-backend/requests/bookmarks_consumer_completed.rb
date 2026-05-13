module TestkitBackend
  module Requests
    # Frontend response to a backend->frontend
    # BookmarksConsumerRequest. We never emit one. Stub for parity.
    class BookmarksConsumerCompleted < Request
      def process
        raise NotImplementedError,
              'BookmarkManager callbacks are not implemented (driver does not advertise Feature:API:BookmarkManager)'
      end
    end
  end
end
