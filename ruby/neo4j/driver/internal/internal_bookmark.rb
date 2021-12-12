module Neo4j::Driver
  module Internal
    class InternalBookmark
      attr_reader :values

      def initialize(values)
        java.util.Objects.require_non_null(values)
        @values = values
      end

      EMPTY = new(java.util.Collections.empty_set)
    end
  end
end
