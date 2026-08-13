# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents a single record (row) in a result
    class Record
      def initialize(keys, values)
        @keys = keys
        @values = values
        # keys arrive already symbolized (Session/Transaction map the RUN
        # response fields with &:to_sym), so the map is symbol-keyed — to_h
        # then returns symbol keys, matching the JRuby flavour and the rest
        # of the API (labels, rel types, property keys are all symbols).
        @map = keys.zip(values).to_h
      end

      attr_reader :keys, :values

      def [](key)
        case key
        when Integer
          @values[key]
        when String, Symbol
          @map[key.to_sym]
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

      def each(&)
        @map.each(&)
      end
    end
  end
end
