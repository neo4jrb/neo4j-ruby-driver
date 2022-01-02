module Neo4j::Driver
  module Internal
    class InternalPath < Array
      attr_reader :nodes, :relationships

      class SelfContainedSegment < Struct.new(:start_node, :relationship, :end_node)
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

=begin
      private def endpoint?(node, relationship)
        node.id == relationship.start_node_id || node.id == relationship.end_node_id
      end

      def self.internal_path(alternating_node_and_rel)
        nodes = new_list((alternating_node_and_rel.size / 2) + 1)
        relationship = new_list(alternating_node_and_rel.size / 2)
        segments = new_list(alternating_node_and_rel.size / 2)

        if (alternating_node_and_rel.size % 2) == 0
          raise java.lang.IllegalArgumentException, 'An odd number of entities are required to build a path'
        end

        last_node, last_relationship = nil
        index = 0

        alternating_node_and_rel.each do |entity|
          raise java.lang.IllegalArgumentException, 'Path entities cannot be null' if entity.nil?

          if index.even?
            # even index - this should be a node
            last_node = entity
            if nodes.empty? || endpoint?(last_node, last_relationship)
              nodes >> last_node
            else
              raise java.lang.IllegalArgumentException, "Node argument #{index} is not an endpoint of relationship argument #{index - 1}"
            end
          else
            # odd index - this should be a relationship
            last_relationship = entity

            if endpoint?(last_node, last_relationship)
              relationship >> last_relationship
            else
              raise java.lang.IllegalArgumentException, "Node argument #{index - 1} is not an endpoint of relationship argument #{index}"
            end
          end

          index += 1
        end

        build_segments
      end

      private def new_list(size)
        size == 0 ? [] : Array.new(size)
      end
=end

      private

      def entities
        nodes + relationships
      end

=begin

      def build_segments
        relationships.each do |index|
          segments << SelfContainedSegment.new(nodes[index], relationships[index], nodes[index + 1])
        end
      end
=end
    end
  end
end
