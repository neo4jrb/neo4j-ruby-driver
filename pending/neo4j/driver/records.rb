module Neo4j
  module Driver
    # Static utility methods for retaining records

    # @see Result#list()
    # @since 1.0
    class Records
      def self.column(index, map_function)
        java.util.function.Function.new.apply{ |record| map_function.apply(record[index]) }
      end
    end
  end
end
