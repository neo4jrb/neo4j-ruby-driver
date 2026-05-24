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
        include ConfigConverter

        def default_manager(initial_bookmarks: nil, bookmarks_supplier: nil, bookmarks_consumer: nil)
          super(to_java_config(Neo4j::Driver::BookmarkManagerConfig, initial_bookmarks:, bookmarks_supplier:, bookmarks_consumer:))
        end
      end
    end
  end
end
