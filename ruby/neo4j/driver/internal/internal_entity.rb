module Neo4j::Driver
  module Internal
    class InternalEntity
      attr_reader :id, :properties
      delegate :hash, to: :id
      delegate :[], :size, :key?, :keys, :values, :to_h, to: :properties

      def initialize(id, properties)
        @id = id
        @properties = properties
      end

      def ==(other)
        equal?(other) || self.class == other.class && id == other.id
      end

      alias eql? ==
    end
  end
end
