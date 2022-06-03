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

      def eql?(other)
        id.eql?(other.id)
      end

      def ==(other)
        id == other.id
      end
    end
  end
end
