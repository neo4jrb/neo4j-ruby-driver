# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalRecord
      include Conversions
      delegate :first, to: :@values

      def initialize(keys, connection)
        @keys = keys
        values = Bolt::Connection.field_values(connection)
        @values = Array.new(keys.size) { |i| to_typed_value(Bolt::List.value(values, i)) }
      end

      def [](key)
        @values[key.is_a?(Integer) ? key : @keys.index(key)]
      end

      private

      def to_typed_value(value)
        case Bolt::Value.type(value)
        when :bolt_string
          to_string(value)
        when :bolt_integer
          Bolt::Integer.get(value)
        else
          to_string(value)
        end
      end
    end
  end
end
