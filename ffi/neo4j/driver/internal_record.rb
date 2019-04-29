# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalRecord
      include Conversions
      delegate :first, to: :@values

      def initialize(keys, connection)
        @keys = keys
        values = Bolt::Connection.field_values(connection)
        @values = Array.new(keys.size) { |i| Value.to_ruby(Bolt::List.value(values, i)) }
      end

      def [](key)
        @values[key.is_a?(Integer) ? key : @keys.index(key)]
      end
    end
  end
end
