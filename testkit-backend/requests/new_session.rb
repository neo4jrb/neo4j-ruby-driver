# frozen_string_literal: true

module TestkitBackend
  module Requests
    class NewSession < Data.define(:driver_id, :access_mode, :database, :bookmarks)
      include Request

      def execute
        session = registry.fetch(driver_id).session(build_options)
        Response::Session.new(id: registry.store(session))
      end

      private

      def build_options
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
