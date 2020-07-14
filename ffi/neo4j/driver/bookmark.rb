# frozen_string_literal: true

module Neo4j
  module Driver
    class Bookmark < Set
      alias to_set itself

      def self.from(set)
        new(set)
      end
    end
  end
end
