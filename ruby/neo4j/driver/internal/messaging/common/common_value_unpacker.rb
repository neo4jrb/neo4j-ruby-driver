module Neo4j::Driver
  module Internal
    module Messaging
      module Common
        class CommonValueUnpacker
          DATE = 'D'
          DATE_STRUCT_SIZE = 1
          TIME = 'T'
          TIME_STRUCT_SIZE = 2
          LOCAL_TIME = 't'
          LOCAL_TIME_STRUCT_SIZE = 1
          LOCAL_DATE_TIME = 'd'
          LOCAL_DATE_TIME_STRUCT_SIZE = 2
          DATE_TIME_WITH_ZONE_OFFSET = 'F'
          DATE_TIME_WITH_ZONE_ID = 'f'
          DATE_TIME_STRUCT_SIZE = 3
          DURATION = 'E'
          DURATION_TIME_STRUCT_SIZE = 4
          POINT_2D_STRUCT_TYPE = 'X'
          POINT_2D_STRUCT_SIZE = 3
          POINT_3D_STRUCT_TYPE = 'Y'
          POINT_3D_STRUCT_SIZE = 4
          NODE = 'N'
          RELATIONSHIP = 'R'
          UNBOUND_RELATIONSHIP = 'r'
          PATH = 'P'
          NODE_FIELDS = 3

          attr_reader :unpacker

          delegate :unpack_struct_header, :unpack_struct_signature, to: :unpacker

          def initialize(input)
            @unpacker = Packstream::PackStream::Unpacker.new(input)
          end

          def unpack_map
            size = unpacker.unpack_map_header.to_i

            return java.util.Collections.empty_map if size == 0

            map = Util::Iterables.new_hash_map_with_size(size)

            size.times do
              key = unpacker.unpack_string
              map[key] = unpack
            end

            map
          end

          def unpack_array
            size = unpacker.unpack_list_header.to_i
            values = []

            size.times{ values << unpack }

            values
          end

          def unpack
            type = unpacker.peek_next_type

            case type
            when NilClass
              Values.value(unpacker.unpack_null)
            when FalseClass || TrueClass
              Values.value(unpacker.unpack_boolean)
            when Integer
              Values.value(unpacker.unpack_long)
            when Float
              Values.value(unpacker.unpack_double)
            when BYTES
              Values.value(unpacker.unpack_bytes)
            when String
              Values.value(unpacker.unpack_string)
            when Hash
              Value::MapValue.new(unpack_map)
            when Array
              size = unpacker.unpack_list_header.to_i

              vals = []

              size.times{ vals << unpack }

              Value::ListValue.new(vals)
            when STRUCT
              size = unpacker.unpack_struct_header.to_i
              struct_type = unpacker.unpack_struct_signature

              unpack_struct(size, struct_type)
            else
              raise java.io.IOException, "Unknown value type: #{type}"
            end
          end

          def unpack_struct(size, type)
            case type
            when DATE
              ensure_correct_struct_size(Types::TypeConstructor::DATE, DATE_STRUCT_SIZE, size)
              unpack_date
            when TIME
              ensure_correct_struct_size(Types::TypeConstructor::TIME, TIME_STRUCT_SIZE, size)
              unpack_time
            when LOCAL_TIME
              ensure_correct_struct_size(Types::TypeConstructor::LOCAL_TIME, LOCAL_TIME_STRUCT_SIZE, size)
              unpack_local_time
            when LOCAL_DATE_TIME
              ensure_correct_struct_size(Types::TypeConstructor::LOCAL_DATE_TIME, LOCAL_DATE_TIME_STRUCT_SIZE, size)
              unpack_local_date_time
            when DATE_TIME_WITH_ZONE_OFFSET
              ensure_correct_struct_size(Types::TypeConstructor::DATE_TIME_WITH_ZONE_OFFSET, DATE_TIME_STRUCT_SIZE, size)
              unpack_date_time_with_zone_offset
            when DATE_TIME_WITH_ZONE_ID
              ensure_correct_struct_size(Types::TypeConstructor::DATE_TIME_WITH_ZONE_ID, DATE_TIME_STRUCT_SIZE, size)
              unpack_date_time_with_zone_id
            when DURATION
              ensure_correct_struct_size(Types::TypeConstructor::DURATION, DURATION_TIME_STRUCT_SIZE, size)
              unpack_duration
            when POINT_2D_STRUCT_TYPE
              ensure_correct_struct_size(Types::TypeConstructor::POINT, POINT_2D_STRUCT_SIZE, size)
              unpack_point2_d
            when POINT_3D_STRUCT_TYPE
              ensure_correct_struct_size(Types::TypeConstructor::POINT, POINT_3D_STRUCT_SIZE, size)
              unpack_point3_d
            when NODE
              ensure_correct_struct_size(Types::TypeConstructor::NODE, NODE_FIELDS, size)
              adapted = unpack_node
              Value::NodeValue.new(adapted)
            when RELATIONSHIP
              ensure_correct_struct_size(Types::TypeConstructor::RELATIONSHIP, 5, size)
              unpack_relationship
            when PATH
              ensure_correct_struct_size(Types::TypeConstructor::PATH, 3, size)
              unpack_path
            else
              raise java.io.IOException, "Unknown struct type: #{type}"
            end
          end

          private

          def unpack_relationship
            urn = unpacker.unpack_long
            start_urn = unpacker.unpack_long
            end_urn = unpacker.unpack_long
            rel_type = unpacker.unpack_string
            props = unpack_map

            adapted = InternalRelationship.new(urn, start_urn, end_urn, rel_type, props)
            Value::RelationshipValue.new(adapted)
          end

          def unpack_node
            urn = unpacker.unpack_long

            num_labels = unpacker.unpack_list_header.to_i
            labels = []

            num_labels.times{ labels << unpacker.unpack_string }

            num_props = unpacker.unpack_map_header.to_i
            props = Util::Iterables.new_hash_map_with_size(num_props)

            num_props.times do
              key = unpacker.unpack_string
              props[key] = unpack
            end

            InternalNode.new(urn, labels, props)
          end

          def unpack_path
            # List of unique nodes
            uniq_nodes = Array.new(unpacker.unpack_list_header.to_i)

            uniq_nodes.length.times do |index|
              ensure_correct_struct_size(Types::TypeConstructor::NODE, NODE_FIELDS, unpacker.unpack_struct_header)
              ensure_correct_struct_signature("NODE", NODE, unpacker.unpack_struct_signature)
              uniq_nodes[index] = unpack_node
            end

            # List of unique relationships, without start/end information
            uniq_rels = Array.new(unpacker.unpack_list_header.to_i)
            uniq_rels.length.times do |index|
              ensure_correct_struct_size(Types::TypeConstructor::RELATIONSHIP, 3, unpacker.unpack_struct_header)
              ensure_correct_struct_signature("UNBOUND_RELATIONSHIP", UNBOUND_RELATIONSHIP, unpacker.unpack_struct_signature)
              id = unpacker.unpack_long
              rel_type = unpacker.unpack_string
              props = unpack_map
              uniq_rels[index] = InternalRelationship.new(id, -1, -1, rel_type, props)
            end

            # Path sequence
            length = unpacker.unpack_list_header.to_i

            # Knowing the sequence length, we can create the arrays that will represent the nodes, rels and segments in their "path order"
            segments = Array.new(length/2)
            nodes = Array.new(segments.length + 1)
            rels = Array.new(segments.length)

            prev_node = uniq_nodes.first # Start node is always 0, and isn't encoded in the sequence
            nodes[0] = prev_node

            segments.length.times do |index|
              rel_idx = unpacker.unpack_long.to_i

              next_node = uniq_nodes[rel_idx]

              # Negative rel index means this rel was traversed "inversed" from its direction
              if rel_idx < 0
                rel = uniq_rels[(-rel_idx) - 1] # -1 because rel idx are 1-indexed
                rel.set_start_and_end(next_node.id, prev_node.id)
              else
                rel = uniq_rels[rel_idx - 1]
                rel.set_start_and_end(prev_node.id, next_node.id)
              end

              nodes[index + 1] = next_node
              rels[index] = rel
              segments[index] = InternalPath::SelfContainedSegment.new(prev_node, rel, next_node)
              prev_node = next_node
            end

            Value::PathValue.new(InternalPath.new(segments, nodes, rels))
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
            epoch_day = unpacker.unpack_long
            Values.value(java.time.LocalDate.of_epoch_day(epoch_day))
          end

          def unpack_time
            nano_of_day_local = unpacker.unpack_long
            offset_seconds = java.lang.Math.to_int_exact(unpacker.unpack_long)

            local_time = java.time.LocalTime.of_nano_of_day(nano_of_day_local)
            offset = java.time.ZoneOffset.of_total_seconds(offset_seconds)
            Values.value( java.time.OffsetTime.of(local_time, offset))
          end

          def unpack_local_time
            nano_of_day_local = unpacker.unpack_long
            Values.value(java.time.LocalTime.of_nano_of_day(nano_of_day_local))
          end

          def unpack_local_date_time
            epoch_second_utc = unpacker.unpack_long
            nano = java.lang.Math.to_int_exact(unpacker.unpack_long)
            Values.value( java.time.LocalDateTime.of_epoch_second(epoch_second_utc, nano, UTC))
          end

          def unpack_date_time_with_zone_offset
            epoch_second_local = unpacker.unpack_long
            nano = java.lang.Math.to_int_exact(unpacker.unpack_long)
            offset_seconds = java.lang.Math.to_int_exact(unpacker.unpack_long)
            Values.value( new_zoned_date_time(epoch_second_local, nano, java.time.ZoneOffset.of_total_seconds(offset_seconds)))
          end

          def unpack_date_time_with_zone_id
            epoch_second_local = unpacker.unpack_long
            nano = java.lang.Math.to_int_exact(unpacker.unpack_long)
            zone_id_string = unpacker.unpack_string
            Values.value(new_zoned_date_time(epoch_second_local, nano, java.time.ZoneId.of(zone_id_string)))
          end

          def unpack_duration
            months = unpacker.unpack_long
            days = unpacker.unpack_long
            seconds = unpacker.unpack_long
            nanoseconds = java.lang.Math.to_int_exact(unpacker.unpack_long)
            Values.iso_duration(months, days, seconds, nanoseconds)
          end

          def unpack_point2_d
            srid = java.lang.Math.to_int_exact(unpacker.unpack_long)
            x = unpacker.unpack_double
            y = unpacker.unpack_double
            Values.point(srid, x, y)
          end

          def unpack_point3_d
            srid = java.lang.Math.to_int_exact(unpacker.unpack_long)
            x = unpacker.unpack_double
            y = unpacker.unpack_double
            z = unpacker.unpack_double
            Values.point(srid, x, y, z)
          end

          def self.new_zoned_date_time(epoch_second_local, nano, zone_id)
            instant = java.time.Instant.of_epoch_second(epoch_second_local, nano)
            local_date_time = java.time.LocalDateTime.of_instant(instant, UTC)
            java.time.ZonedDateTime.of(local_date_time, zone_id)
          end
        end
      end
    end
  end
end
