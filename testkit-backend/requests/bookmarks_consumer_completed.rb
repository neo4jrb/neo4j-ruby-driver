module TestkitBackend
  module Requests
    # Frontend reply to a backend->frontend BookmarksConsumerRequest, read
    # inline by NewBookmarkManager#consume. Writes no response of its own —
    # cf. ResolverResolutionCompleted.
    class BookmarksConsumerCompleted < Request
      def process; end
    end
  end
end
