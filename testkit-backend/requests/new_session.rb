module TestkitBackend
  module Requests
    class NewSession < Request
      def process
        reference('Session')
      end

      def to_object
        fetch(driver_id).session(
          default_access_mode: access_mode == 'r' ? Neo4j::Driver::AccessMode::READ : Neo4j::Driver::AccessMode::WRITE,
          bookmarks: bookmarks&.map(&Neo4j::Driver::Bookmark.method(:from)),
          database: database,
          fetch_size: fetch_size,
          impersonated_user: impersonated_user,
          bookmark_manager: (fetch(bookmark_manager_id) if bookmark_manager_id),
          auth_token: (Request.object_from(authorization_token) if authorization_token)
        )
      end
    end
  end
end