# frozen_string_literal: true

require 'active_support/core_ext/array/grouping'

module Neo4j
  module Driver
    module Internal
      module PathValue
        CODE = :P
        extend StructureValue
        class << self
          def to_ruby_value(uniq_nodes, uniq_rels, sequence)
            prev_node = uniq_nodes.first
            nodes = [prev_node] # Start node is always 0, and isn't encoded in the sequence
            rels = []
            path = Types::Path.new(nodes, rels)
            sequence.in_groups_of(2) do |node_idx, rel_idx|
              node = uniq_nodes[node_idx]
              nodes << node
              rel = uniq_rels[rel_idx.abs - 1] # -1 because rel idx are 1-indexed
              update(rel, prev_node, node, rel_idx.negative?)
              rels << rel
              path << Types::Path::Segment.new(prev_node, rel, node)
              prev_node = node
            end
            path
          end

          private

          def update(rel, prev_node, node, inversed)
            # Negative rel index means this rel was traversed "inversed" from its direction
            prev_node, node = node, prev_node if inversed
            rel.start_node_id = prev_node.id
            rel.end_node_id = node.id
          end
        end
      end
    end
  end
end
