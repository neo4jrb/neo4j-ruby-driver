module Neo4j
  module Driver
    # Causal chaining is carried out by passing bookmarks between transactions.

    # When starting a session with initial bookmarks, the first transaction will be ensured to run at least after
    # the database is as up-to-date as the latest transaction referenced by the supplied bookmarks.

    # Within a session, bookmark propagation is carried out automatically.
    # Thus all transactions in a session (both managed and unmanaged) are guaranteed to be carried out one after another.

    # To opt out of this mechanism for unrelated units of work, applications can use multiple sessions.
    module Bookmark
      # Reconstruct bookmark from \bookmarks string values.
      # @param values values obtained from a previous bookmark.
      # @return A bookmark.
      def self.from(values)
        Internal::InternalBookmark.parse(values)
      end
    end
  end
end
