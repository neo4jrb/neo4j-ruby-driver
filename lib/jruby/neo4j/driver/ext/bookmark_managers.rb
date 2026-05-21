# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Mirrors Java's `BookmarkManagers.defaultManager(BookmarkManagerConfig)`
      # factory (cf. Ext::AuthTokens / Ext::GraphDatabase), but with a Ruby
      # keyword-arg surface instead of a config builder. The supplier/consumer
      # callbacks are plain Procs — JRuby coerces them to the Java
      # Supplier<Set<Bookmark>> / Consumer<Set<Bookmark>> functional interfaces.
      module BookmarkManagers
        def default_manager(initial_bookmarks: nil, bookmarks_supplier: nil, bookmarks_consumer: nil)
          builder = Neo4j::Driver::BookmarkManagerConfig.builder
          builder = builder.with_initial_bookmarks(java.util.HashSet.new(initial_bookmarks)) if initial_bookmarks
          builder = builder.with_bookmarks_supplier(bookmarks_supplier) if bookmarks_supplier
          builder = builder.with_bookmarks_consumer(bookmarks_consumer) if bookmarks_consumer
          super(builder.build)
        end
      end
    end
  end
end
