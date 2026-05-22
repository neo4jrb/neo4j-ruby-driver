module TestkitBackend
  module Requests
    # Frontend reply to a backend->frontend BookmarksSupplierRequest. It is
    # read inline by NewBookmarkManager#supply (which pulls `.bookmarks` off
    # this message), so `process` writes no response of its own — cf.
    # ResolverResolutionCompleted.
    class BookmarksSupplierCompleted < Request
      def process; end
    end
  end
end
