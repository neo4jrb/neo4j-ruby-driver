# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalRecord
      include Conversions
      delegate :first, to: :@field_values

      def initialize(field_names, connection)
        field_values = Bolt::Connection.field_values(connection)
        @field_values =
          Array.new(field_names.size) { |i| to_typed_value(Bolt::List.value(field_values, i)) }
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
