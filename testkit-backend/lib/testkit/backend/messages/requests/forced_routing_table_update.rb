module Testkit::Backend::Messages
  module Requests
    class ForcedRoutingTableUpdate < Request
      def process
        named_entity('Driver', id: driverId)
      end

      def to_object
        fetch(driverId).session(
          bookmarks: bookmarks&.map { |bookmark| Neo4j::Driver::Bookmark.from(Array(bookmark)) },
          database: database
          )
      end
    end
  end
end
