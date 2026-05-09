# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Mirror of testkit's NewSession. Captures every field the protocol
    # may send; fields without a driver counterpart are received but
    # silently ignored at session-construction time (see TODO list in
    # `build_options`).
    class NewSession < Data.define(
      :driver_id,
      :access_mode,
      :bookmarks,
      :database,
      :fetch_size,
      :impersonated_user,
      :bookmark_manager_id,
      :authorization_token,
      :notifications_min_severity,
      :notifications_disabled_categories,
      :disable_auto_commit_retries
    )
      include Request

      def execute
        session = registry.fetch(driver_id).session(build_options)
        Response::Session.new(id: registry.store(session))
      end

      private

      def build_options
        # Driver-supported options. Fields received but not wired through
        # yet (driver gap):
        #   fetch_size, impersonated_user, bookmark_manager_id,
        #   authorization_token (per-session auth), notifications_*,
        #   disable_auto_commit_retries.
        # Promote each as the driver feature lands.
        {
          default_access_mode: access_mode_const,
          database: database,
          bookmarks: bookmarks
        }.compact
      end

      def access_mode_const
        return nil if access_mode.nil?

        access_mode == 'r' ? Neo4j::Driver::AccessMode::READ : Neo4j::Driver::AccessMode::WRITE
      end
    end
  end
end
