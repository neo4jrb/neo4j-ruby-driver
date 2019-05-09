# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class Path < Array
        attr_reader :modes, :relationships

        class Segment
          attr_reader :start_node, :relationship, :end_node

          def initialize(start_node, relationship, end_node)
            @start_node = start_node
            @relationship = relationship
            @end_node = end_node
          end
        end

        def initialize(nodes, relationships)
          super()
          @nodes = nodes
          @relationships = relationships
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
end
