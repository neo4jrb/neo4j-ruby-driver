# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Represents a Path in the Neo4j graph
      # A path is a sequence of alternating nodes and relationships
      class Path
        include Enumerable

        attr_reader :nodes, :relationships

        def initialize(nodes, relationships, segments)
          @nodes = nodes
          @relationships = relationships
          @segments = segments
        end

        # Returns the start node of the path
        def start
          @nodes.first
        end
        alias start_node start

        # Returns the end node of the path
        def end
          @nodes.last
        end
        alias end_node end

        # Returns the number of relationships in the path (number of segments)
        def length
          @relationships.length
        end

        # Check if the path contains the given node
        def contains_node?(node)
          @nodes.any? { |n| n.id == node.id }
        end

        # Check if the path contains the given relationship
        def contains_relationship?(relationship)
          @relationships.any? { |r| r.id == relationship.id }
        end

        # Iterate over segments in the path
        # Each segment represents a relationship and its start/end nodes
        def each(&block)
          @segments.each(&block)
        end

        # Represents a segment of a path (a relationship and its start/end nodes)
        class Segment
          attr_reader :start_node, :end_node, :relationship

          def initialize(start_node, end_node, relationship)
            @start_node = start_node
            @end_node = end_node
            @relationship = relationship
          end

          alias start start_node
          alias end end_node
        end
      end
    end
  end
end
