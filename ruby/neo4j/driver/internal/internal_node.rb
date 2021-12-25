module Neo4j::Driver
  module Internal

    # {@link Node} implementation that directly contains labels and properties.
    class InternalNode < InternalEntity
      attr_reader :labels

      def initialize(id, labels = [], properties = {})
        super(id, labels, properties)
        @labels = labels
      end

      def has_label?(label)
        labels.include?(label)
      end

      def as_value
        Value.NodeValue.new(self)
      end

      def to_s
        ["node<#{id}>"]
      end
    end
  end
end
