module TestkitBackend
  module Requests
    # See BookmarksConsumerCompleted.
    class BookmarksSupplierCompleted < Request
      def process
        raise NotImplementedError,
              'BookmarkManager callbacks are not implemented (driver does not advertise Feature:API:BookmarkManager)'
      end
    end
  end
end
