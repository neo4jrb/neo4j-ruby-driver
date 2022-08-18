module Neo4j
  module Driver
    module Values
      def self.value(value)
        this_method = method(:value)
        case value
        when nil, TrueClass, FalseClass, Integer, Float, String, Symbol, Bookmark, ActiveSupport::Duration,
          Types::Point, Types::Time, Time, Date
          value
        when Hash
          value.transform_keys(&this_method).transform_values(&this_method)
        when Internal::InternalPath
          nonconvertible(value)
        when Enumerable
          value.map(&this_method)
        else
          nonconvertible(value)
        end
      end

      def self.nonconvertible(value)
        raise Exceptions::ClientException, "Unable to convert #{value.class.name} to Neo4j Value."
      end
    end
  end
end
