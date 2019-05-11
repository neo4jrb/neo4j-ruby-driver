# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalRecord
      delegate :first, to: :@values

      def initialize(keys, connection)
        @keys = keys
        @values = Neo4j::Driver::Value.to_ruby(Bolt::Connection.field_values(connection))
      end

      def [](key)
        @values[key.is_a?(Integer) ? key : @keys.index(key.to_s)]
      end
    end
  end
end
