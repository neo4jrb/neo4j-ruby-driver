module Neo4j::Driver
  module Internal
    class InternalPath < Array
      attr_reader :nodes, :relationships

      class Segment < Struct.new(:start_node, :relationship, :end_node)
        def to_s
          sprintf(relationship.start_node_id == start_node.id ? '(%s)-[%s:%s]->(%s)' : '(%s)<-[%s:%s]-(%s)',
                  start_node.id, relationship.id, relationship.type, end_node.id)
        end
      end

      delegate :length, to: :relationships
      delegate :include?, to: :entities

      def initialize(nodes, relationships)
        super()
        @nodes = nodes
        @relationships = relationships
      end

      def to_s
        'path' + super
      end

      def start_node
        @nodes.first
      end

      def end_node
        @nodes.last
      end
    end
  end
end
