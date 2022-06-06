module Neo4j::Driver
  module Internal
    module Async
      class ImmutableConnectionContext
        attr :database_name, :mode, :rediscovery_bookmark, :impersonated_user

        def initialize(database_name, bookmark, mode)
          @database_name = database_name
          @rediscovery_bookmark = bookmark
          @mode = mode
        end

        SINGLE_DB_CONTEXT = new(DatabaseNameUtil::DEFAULT_DATABASE, InternalBookmark::EMPTY, AccessMode::READ)
        MULTI_DB_CONTEXT = new(DatabaseNameUtil::SYSTEM_DATABASE, InternalBookmark::EMPTY, AccessMode::READ)

        # A simple context is used to test connectivity with a remote server/cluster. As long as there is a read only service, the connection shall be established
        # successfully. Depending on whether multidb is supported or not, this method returns different context for routing table discovery.
        def self.simple(supports_multi_db)
          supports_multi_db ? MULTI_DB_CONTEXT : SINGLE_DB_CONTEXT
        end
      end
    end
  end
end
