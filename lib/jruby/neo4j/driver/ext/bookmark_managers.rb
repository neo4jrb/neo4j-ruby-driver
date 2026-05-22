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
          builder = builder.with_initial_bookmarks(to_java_set(initial_bookmarks)) if initial_bookmarks
          # Wrap the callbacks so callers stay on the common API (Ruby Set of
          # Bookmark): convert the supplier's return to a java.util.Set, and the
          # java.util.Set handed to the consumer back to a Ruby Set.
          builder = builder.with_bookmarks_supplier(-> { to_java_set(bookmarks_supplier.call) }) if bookmarks_supplier
          builder = builder.with_bookmarks_consumer(->(bookmarks) { bookmarks_consumer.call(Set.new(bookmarks)) }) if bookmarks_consumer
          super(builder.build)
        end

        private

        def to_java_set(bookmarks) = java.util.HashSet.new(bookmarks.to_a)
      end
    end
  end
end
