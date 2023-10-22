module Neo4j
  module Driver
    # Bookmark configuration used to configure bookmark manager supplied by {@link BookmarkManagers#defaultManager(BookmarkManagerConfig)}.
    class BookmarkManagerConfig
      attr_reader :initial_bookmarks, :bookmarks_consumer, :bookmarks_supplier
      def initialize(builder)
        @initial_bookmarks = builder.initial_bookmarks
        @bookmarks_consumer = builder.bookmarks_consumer
        @bookmarks_supplier = builder.bookmarks_supplier
      end

      # Creates a new {@link BookmarkManagerConfigBuilder} used to construct a configuration object.
      # @return a bookmark manager configuration builder.
      def builder
        BookmarkManagerConfigBuilder.new
      end

      # Builder used to configure {@link BookmarkManagerConfig} which will be used to create a bookmark manager.
      class BookmarkManagerConfigBuilder
        def with_initial_bookmarks(database_to_bookmarks)
          Internal::Validator.require_non_nil!(database_to_bookmarks)
          @initial_bookmarks = database_to_bookmarks
        end

        # Provide bookmarks consumer.
        # The consumer will be called outside bookmark manager's synchronisation lock.
        # @param bookmarksConsumer bookmarks consumer
        # @return this builder
        def with_bookmarks_consumer(bookmarks_consumer)
          @bookmarks_consumer = bookmarks_consumer
        end

        # Provide bookmarks supplier.
        # The supplied bookmarks will be served alongside the bookmarks served by the bookmark manager. The supplied bookmarks will not be stored nor managed by the bookmark manager.
        # The supplier will be called outside bookmark manager's synchronisation lock.
        # @param bookmarksSupplier the bookmarks supplier
        # @return this builder
        def with_bookmarks_supplier(bookmarks_supplier)
          @bookmarks_supplier = bookmarks_supplier
        end

        def build
          BookmarkManagerConfig.new(self)
        end
      end
    end
  end
end
