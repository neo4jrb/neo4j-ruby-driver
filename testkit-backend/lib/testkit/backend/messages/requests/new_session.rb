module Testkit::Backend::Messages
  module Requests
    class NewSession < Request
      def process
        reference('Session')
      end

      def to_object
        fetch(driver_id).session(
          default_access_mode: access_mode == 'r' ? Neo4j::Driver::AccessMode::READ : Neo4j::Driver::AccessMode::WRITE,
          bookmarks: Neo4j::Driver::Bookmark.from(*bookmarks),
          database: database,
          fetch_size: fetch_size,
          impersonated_user: impersonated_user
        )
      end
    end
  end
end