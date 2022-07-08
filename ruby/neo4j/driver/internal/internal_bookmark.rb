module Neo4j::Driver
  module Internal
    class InternalBookmark
      include Bookmark
      EMPTY = new
      attr :values
      delegate :hash, :empty?, to: :values

      private def initialize(*values)
        @values = values.to_set
      end

      def ==(other)
        equal?(other) || self.class == other.class && values == other.values
      end

      alias eql? ==

      def to_s
        "Bookmark{values=#{values}}"
      end

      class << self
        def empty
          EMPTY
        end

        def from(*bookmarks)
          new(*bookmarks.reduce(Set.new) { |set, bookmark| set + bookmark.values })
        end

        alias parse new
      end
    end
  end
end
