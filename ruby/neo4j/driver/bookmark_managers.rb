module Neo4j
  module Driver
    # Setups new instances of {@link BookmarkManager}.
    class BookmarkManagers
     #  Setups a new instance of bookmark manager that can be used in {@link org.neo4j.driver.SessionConfig.Builder#withBookmarkManager(BookmarkManager)}.
     #  @param config the bookmark manager configuration
     #  @return the bookmark manager
     def self.default_manager(config)
       Internal::Neo4jBookmarkManager.new(config.initial_bookmarks, config.bookmarks_consumer, config.bookmarks_supplier)
     end
    end
  end
end
