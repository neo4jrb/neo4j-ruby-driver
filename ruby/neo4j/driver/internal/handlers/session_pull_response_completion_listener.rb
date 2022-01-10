module Neo4j::Driver
  module Internal
    module Handlers
      class SessionPullResponseCompletionListener
        def initialize(connection, bookmark_holder)
          @connection = connection
          @bookmark_holder = bookmark_holder
        end

        def after_success(metadata)
          release_connection
          @bookmark_holder.bookmark = Util::MetadataExtractor.extract_bookmarks(metadata)
        end

        def after_failure(error)
          case error
          when Exceptions::AuthorizationExpiredException
            @connection.terminate_and_release(Exceptions::AuthorizationExpiredException::DESCRIPTION)
          when Exceptions::ConnectionReadTimeoutException
            @connection.terminate_and_release(error.message)
          else
            release_connection
          end
        end

        private

        def release_connection
          @connection.release
        end
      end
    end
  end
end
