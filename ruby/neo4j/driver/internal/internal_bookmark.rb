module Neo4j::Driver
  module Internal
    class InternalBookmark < Set
      include Bookmark
      EMPTY = new

      def initialize(enum = nil)
        super
        freeze
      end

      def values
        self
      end

      class << self
        def empty
          EMPTY
        end

        def from(bookmarks)
          new(bookmarks&.compact)
        end

        def parse(*values)
          new(values)
        end
      end
    end
  end
end
