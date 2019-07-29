# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Handlers
        class SessionPullAllResponseHandler < PullAllResponseHandler
          def initialize(statement, run_handler, connection, bookmarks_holder, metadata_extractor)
            super(statement, run_handler, connection, metadata_extractor)
            @bookmarks_holder = bookmarks_holder
          end

          def after_success(metadata)
            puts "after_success"
            puts caller_locations
            puts "@bookmarks_holder=#{@bookmarks_holder.object_id}"
            @bookmarks_holder.bookmarks = Bolt::Connection.last_bookmark(bolt_connection).first
            puts @bookmarks_holder.bookmarks.inspect
            release_connection
            # @bookmarks_holder.bookmarks = @metadata_extractor.extract_bookmarks(metadata)
          end

          def after_failure(_error)
            release_connection
          end

          private

          def release_connection
            connection.release
          end
        end
      end
    end
  end
end
