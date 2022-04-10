module Neo4j::Driver
  module Internal
    class InternalBookmark < Set
      private

      EMPTY = new

      public

      def initialize(enum = nil)
        super
        freeze
      end

      def empty
        EMPTY
      end

      def values
        self
      end

      class << self
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
