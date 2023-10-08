module Neo4j::Driver
  module Internal
    module Messaging
      module Common
        module CommonValueUnpacker
          include CommonValue
          NODE = 'N'
          RELATIONSHIP = 'R'
          UNBOUND_RELATIONSHIP = 'r'
          PATH = 'P'
          NODE_FIELDS = 3

          def unpack_map(size)
            size.times.to_h { [unpack.to_sym, unpack] }
          end

          def unpack_array(size)
            size.times.map { unpack }
          end

          def unpack
            marker_byte = read_byte
            marker_high_nibble = marker_byte & 0xF0
            marker_low_nibble = marker_byte & 0x0F

            case marker_high_nibble
            when TINY_STRING
              return unpack_string(marker_low_nibble)
            when TINY_LIST
              return unpack_array(marker_low_nibble)
            when TINY_MAP
              return unpack_map(marker_low_nibble)
            when TINY_STRUCT
              return unpack_struct(marker_low_nibble, read_char)
            end

            case marker_byte & 0xFF # we read a signed byte but markers are unsigned
            when NULL
              nil
            when TRUE
              true
            when FALSE
              false
            when FLOAT_64
              unpack_double
            when BYTES_8
              unpack_bytes(read_ubyte)
            when BYTES_16
              unpack_bytes(read_ushort)
            when BYTES_32
              unpack_bytes(read_uint)
            when STRING_8
              unpack_string(read_ubyte)
            when STRING_16
              unpack_string(read_ushort)
            when STRING_32
              unpack_string(read_uint)
            when LIST_8
              unpack_array(read_ubyte)
            when LIST_16
              unpack_array(read_ushort)
            when LIST_32
              unpack_array(read_uint)
            when MAP_8
              unpack_map(read_ubyte)
            when MAP_16
              unpack_map(read_ushort)
            when STRUCT_8
              unpack_struct(read_ubyte, read_char)
            when STRUCT_16
              unpack_struct(read_ushort, read_char)
            else
              unpack_long(marker_byte)
            end
          end

          def unpack_struct(size, type)
            case type
            when DATE
              ensure_correct_struct_size(:DATE, DATE_STRUCT_SIZE, size)
              unpack_date
            when TIME
              ensure_correct_struct_size(:TIME, TIME_STRUCT_SIZE, size)
              unpack_time
            when LOCAL_TIME
              ensure_correct_struct_size(:LOCAL_TIME, LOCAL_TIME_STRUCT_SIZE, size)
              unpack_local_time
            when LOCAL_DATE_TIME
              ensure_correct_struct_size(:LOCAL_DATE_TIME, LOCAL_DATE_TIME_STRUCT_SIZE, size)
              unpack_local_date_time
            when DATE_TIME_WITH_ZONE_OFFSET
              ensure_correct_struct_size(:DATE_TIME_WITH_ZONE_OFFSET, DATE_TIME_STRUCT_SIZE, size)
              unpack_date_time_with_zone_offset
            when DATE_TIME_WITH_ZONE_ID
              ensure_correct_struct_size(:DATE_TIME_WITH_ZONE_ID, DATE_TIME_STRUCT_SIZE, size)
              unpack_date_time_with_zone_id
            when DURATION
              ensure_correct_struct_size(:DURATION, DURATION_TIME_STRUCT_SIZE, size)
              unpack_duration
            when POINT_2D_STRUCT_TYPE
              ensure_correct_struct_size(:POINT, POINT_2D_STRUCT_SIZE, size)
              unpack_point2_d
            when POINT_3D_STRUCT_TYPE
              ensure_correct_struct_size(:POINT, POINT_3D_STRUCT_SIZE, size)
              unpack_point3_d
            when NODE
              ensure_correct_struct_size(:NODE, NODE_FIELDS, size)
              adapted = unpack_node
            when RELATIONSHIP
              ensure_correct_struct_size(:RELATIONSHIP, 5, size)
              unpack_relationship
            when UNBOUND_RELATIONSHIP
              ensure_correct_struct_size(:RELATIONSHIP, 3, size)
              unpack_unbound_relationship
            when PATH
              ensure_correct_struct_size(:PATH, 3, size)
              unpack_path
            else
              raise IOError, "Unknown struct type: #{type}"
            end
          end

          private

          def unpack_relationship
            InternalRelationship.new(*4.times.map { unpack }, **unpack)
          end

          def unpack_unbound_relationship
            InternalRelationship.new(unpack, nil, nil, unpack, **unpack)
          end

          def unpack_node
            InternalNode.new(unpack, *unpack.map(&:to_sym), **unpack)
          end

          def unpack_path
            uniq_nodes = unpack
            uniq_rels = unpack
            sequence = unpack
            prev_node = uniq_nodes.first
            nodes = [prev_node] # Start node is always 0, and isn't encoded in the sequence
            rels = []
            path = Types::Path.new(nodes, rels)
            sequence.in_groups_of(2) do |rel_idx, node_idx|
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

          def update(rel, prev_node, node, inversed)
            # Negative rel index means this rel was traversed "inversed" from its direction
            prev_node, node = node, prev_node if inversed
            rel.start_node_id = prev_node.id
            rel.end_node_id = node.id
          end

          def ensure_correct_struct_size(type_constructor, expected, actual)
            if expected != actual
              struct_name = type_constructor.to_s
              raise Neo4j::Driver::Exceptions::ClientException, "Invalid message received, serialized #{struct_name} structures should have #{expected} fields, received #{struct_name} structure has #{actual} fields."
            end
          end

          private

          def ensure_correct_struct_signature(struct_name, expected, actual)
            if expected != actual
              struct_name = type_constructor.to_s
              raise Neo4j::Driver::Exceptions::ClientException, "Invalid message received, expected a `#{struct_name}`, signature 0x#{expected.to_i.to_s(16)}. Received signature was 0x#{actual.to_i.to_s(16)}."
            end
          end

          def unpack_date
            EPOCH + unpack
          end

          def time(nano_of_day_local, offset_seconds = nil)
            min, sec = Rational(nano_of_day_local, NANO_FACTOR).divmod(60)
            Time.new(0, 1, 1, *min.divmod(60), sec, offset_seconds)
          end

          def unpack_time
            Types::OffsetTime.new(time(unpack, unpack))
          end

          def unpack_local_time
            Types::LocalTime.new(time(unpack))
          end

          def unpack_local_date_time
            Types::LocalDateTime.new(Time.at(unpack, unpack, :nsec).utc)
          end

          def unpack_date_time_with_zone_offset
            # Time.at(unpack, unpack, :nsec, in: unpack)
            sec = unpack
            nsec = unpack
            offset = unpack
            time = Time.at(sec, nsec, :nsec).utc
            Time.new(time.year, time.month, time.mday, time.hour, time.min, time.sec + Rational(nsec, 1_000_000_000),
                     offset)
          end

          def unpack_date_time_with_zone_id
            time = Time.at(unpack, unpack, :nsec).in_time_zone(TZInfo::Timezone.get(unpack))
            time - time.utc_offset
          end

          def unpack_duration
            DurationNormalizer.create(*4.times.map { unpack })
          end

          def unpack_point2_d
            Types::Point.new(srid: unpack, x: unpack, y: unpack)
          end

          def unpack_point3_d
            Types::Point.new(srid: unpack, x: unpack, y: unpack, z: unpack)
          end
        end
      end
    end
  end
end
