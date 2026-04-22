# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents a single record (row) in a result
    class Record
      def initialize(keys, values)
        @keys = keys
        @values = values
        # Create map with string keys for consistent lookup
        @map = {}
        @keys.each_with_index do |key, idx|
          @map[key.to_s] = @values[idx]
        end
      end

      def keys
        @keys
      end

      def values
        @values
      end

      def [](key)
        case key
        when Integer
          @values[key]
        when String, Symbol
          @map[key.to_s]
        else
          raise ArgumentError, "Invalid key type: #{key.class}"
        end
      end

      def first
        @values.first
      end

      def to_h
        @map.dup
      end

      def each(&block)
        @map.each(&block)
      end
    end
  end
end
