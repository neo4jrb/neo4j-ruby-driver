module Neo4j::Driver
  module Internal
    class InternalEntity < Struct.new(:id, :properties)

      delegate :size, :keys, to: :properties

      def as_map(map_function = Values.of_object)
        Util::Extract.map(properties, map_function)
      end

      def as_value
        Value::MapValue.new(properties)
      end

      def contains_key(key)
        properties.keys.inlucde?(key)
      end

      def get(key)
        value = properties[key]
        value.nil? ? nil : value
      end

      def values(map_function)
        Util::Iterables.map(properties.values, map_function)
      end
    end
  end
end
