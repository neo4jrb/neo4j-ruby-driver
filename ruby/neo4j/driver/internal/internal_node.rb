module Neo4j::Driver
  module Internal
    # {@link Node} implementation that directly contains labels and properties.
    class InternalNode < InternalEntity
      attr_reader :labels

      def initialize(id, *labels, **properties)
        super(id, properties)
        @labels = labels
      end

      def label?(label)
        labels.include?(label)
      end

      def to_s
        "node<#{id}>"
      end
    end
  end
end
