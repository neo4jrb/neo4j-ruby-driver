# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Java's BookmarkManager exposes `getBookmarks()`, which JRuby
      # naturally surfaces as `get_bookmarks`. The MRI flavour's API
      # is `bookmarks` (Ruby convention drops the `get_` prefix), so
      # alias it on the Java interface too — gives cross-flavour
      # parity for any caller introspecting the manager directly.
      module BookmarkManager
        def bookmarks = get_bookmarks
      end
    end
  end
end
