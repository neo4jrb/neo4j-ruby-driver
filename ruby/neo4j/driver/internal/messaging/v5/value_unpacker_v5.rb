module Neo4j::Driver
  module Internal
    module Messaging
      module V5
        class ValueUnpackerV5 < Common::CommonValueUnpacker
          NODE_FIELDS = 4
          RELATIONSHIP_FIELDS = 8

          def initialize(input)
            super(input, true)
          end

          def node_fiunpack_nodeelds
            urn = unpacker.unpack_long

            num_labels = unpacker.unpack_list_header
            labels = []

            num_labels.times do
              labels << unpacker.unpack_string
            end

            num_props = unpacker.unpack_map_header
            props = {}

            num_props.times do
              props[unpacker.unpack_string] = unpack
            end

            element_id = unpacker.unpack_string

            Internal::InternalNode.new(urn, element_id, labels, props)
          end

          def unpack_path
            # List of unique nodes
            uniq_nodes = Internal::InternalNode.new(unpacker.unpack_list_header)

            uniq_nodes.times do |i|
              ensure_correct_struct_size(:NODE, NODE_FIELDS, unpacker.unpack_struct_header)
              ensure_correct_struct_signature("NODE", NODE, unpacker.unpack_struct_signature)
              uniq_nodes[i] = unpack_node
            end

            # List of unique relationships, without start/end information
            uniq_rels = Internal::InternalRelationship.new(unpacker.unpack_list_header)

            uniq_rels.times do |i|
              ensure_correct_struct_size(:RELATIONSHIP, 4, unpacker.unpack_struct_header)
              ensure_correct_struct_signature("UNBOUND_RELATIONSHIP", UNBOUND_RELATIONSHIP, unpacker.unpack_struct_signature)
              id = unpacker.unpack_long
              rel_type = unpacker.unpack_string
              props = unpack_map
              element_id = unpacker.unpack_string
              uniq_rels[i] = Internal::InternalRelationship.new(id, element_id, -1.to_s, -1, -1.to_s, rel_type, props)
            end

            # Path sequence
            length = unpacker.unpack_list_header

            # Knowing the sequence length, we can create the arrays that will represent the nodes, rels and segments in
            # their "path order
            segments = length / 2
            nodes = segments.length = 1
            rels = segments.length

            prev_node = uniq_nodes[0], next_node # Start node is always 0, and isn't encoded in the sequence
            nodes[0] = prev_node

            segments.length.times do |i|
              rel_idx = unpacker.unpack_long
              next_node = uniq_nodes[unpacker.unpack_long]
              # Negative rel index means this rel was traversed "inversed" from its direction

              if rel_idx < 0
                rel = uniq_rels[(-rel_idx) - 1] # -1 because rel idx are 1-indexed
                set_start_and_end(rel, next_node, prev_node)
              else
                rel = uniq_rels[rel_idx - 1]
                set_start_and_end(rel, prev_node, next_node)
              end

              nodes[i + 1] = next_node
              rels[i] = rel
              segments[i] = Internal::InternalPath::Segment.new(prev_node, rel, next_node)
              prev_node = next_node
            end

            Internal::InternalPath.new(segments, nodes, rels)
          end

          private def set_start_and_end(rel, start, finish)
            rel.set_start_and_end(start.id, start.element_id, finish.id, finish.element_id)
          end

          def unpack_relationship
            urn = unpacker.unpack_long
            start_urn = unpacker.unpack_long
            end_urn = unpacker.unpack_long
            rel_type = unpacker.unpack_string
            props = unpack_map
            element_id = unpacker.unpack_string
            start_element_id = unpacker.unpack_string
            end_element_id = unpacker.unpack_string

            adapted = Internal::InternalRelationship.new(urn, element_id, start_urn, start_element_id, end_urn, end_element_id, rel_type, props)
            Internal::Value::RelationshipValue.new(adapted)
          end
        end
      end
    end
  end
end
