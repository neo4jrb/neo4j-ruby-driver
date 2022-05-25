module Neo4j::Driver
  module Internal
    class InternalEntity
      attr_reader :id, :properties
      delegate :eql?, :hash, :==, to: :id
      delegate :[], :size, :key?, :keys, :values, :to_h, to: :properties

      def initialize(id, properties)
        @id = id
        @properties = properties
      end
    end
  end
end
