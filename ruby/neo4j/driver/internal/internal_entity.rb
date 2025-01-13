module Neo4j::Driver
  module Internal
    class InternalEntity
      attr_reader :id, :element_id, :properties
      delegate :hash, to: :id
      delegate :[], :size, :key?, :keys, :values, :to_h, to: :properties

      def initialize(id, element_id, **properties)
        @id = id
        @element_id = element_id || id.to_s
        @properties = properties
      end

      def ==(other)
        equal?(other) || self.class == other.class && id == other.id
      end

      alias eql? ==
    end
  end
end
