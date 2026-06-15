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
          auth_token: (Request.object_from(authorization_token) if authorization_token),
          auto_commit_retries_mode: auto_commit_retries_mode
        )
      end

      private

      # Feature:IdempotentRetries — SessionConfig#withAutoCommitRetriesMode takes
      # a tri-state AutoCommitRetriesMode, so hand the converter that enum
      # directly (the driver Config, by contrast, takes a plain boolean). nil
      # leaves it unset => DEFAULT (inherit the driver). AutoCommitRetriesMode is
      # defined on both flavors (Java enum on JRuby, symbols on MRI), so naming
      # it here keeps the backend flavor-agnostic.
      def auto_commit_retries_mode
        return if disable_auto_commit_retries.nil?

        disable_auto_commit_retries ? Neo4j::Driver::AutoCommitRetriesMode::DISABLED : Neo4j::Driver::AutoCommitRetriesMode::ENABLED
      end
    end
  end
end