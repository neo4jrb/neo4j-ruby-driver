module Testkit::Backend::Messages
  module Requests
    class NewSession < Request
      def process
        reference('Session')
      end

      def to_object
        fetch(driverId).session(
          default_access_mode: accessMode == 'r' ? Neo4j::Driver::AccessMode::READ : Neo4j::Driver::AccessMode::WRITE,
          bookmarks: bookmarks&.map { |bookmark| Neo4j::Driver::Bookmark.from(Array(bookmark)) },
          database: database,
          fetch_size: fetchSize
        )
      end
    end
  end
end