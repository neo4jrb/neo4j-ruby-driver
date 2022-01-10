module Neo4j::Driver
  module Internal
    class InternalBookmark < Set
      def initialize(enum = nil)
        super
        freeze
      end

      def values
        self
      end

      EMPTY = new

      class << self
        def from(bookmarks)
          new(bookmarks.flatten)
        end

        def parse(*values)
          new(values)
        end
      end
    end
  end
end
