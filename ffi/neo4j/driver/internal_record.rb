# frozen_string_literal: true
module Neo4j
  module Driver
    class InternalRecord
      include Conversions
      delegate :first, to: :@field_values

      def initialize(field_names, connection)
        field_values = Bolt::Connection.field_values(connection)
        @field_values = field_names.size.times
                          .map { |i| Bolt::Values.bolt_list_value(field_values, i) }
                          .map(&method(:to_typed_value))
      end

      private

      def to_typed_value(value)
        case Bolt::Values.bolt_value_type(value)
        when :bolt_string
          to_string(value)
        when :bolt_integer
          Bolt::Values.bolt_integer_get(value)
        else
          to_string(value)
        end
      end
    end
  end
end
