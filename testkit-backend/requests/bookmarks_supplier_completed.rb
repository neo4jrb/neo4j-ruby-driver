module TestkitBackend
  module Requests
    # See BookmarksConsumerCompleted.
    class BookmarksSupplierCompleted < Request
      def process
        named_entity('BackendError',
                     msg: 'BookmarkManager callbacks are not implemented (driver does not advertise Feature:API:BookmarkManager)')
      end
    end
  end
end
