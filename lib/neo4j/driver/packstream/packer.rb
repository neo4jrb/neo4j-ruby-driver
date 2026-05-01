# frozen_string_literal: true

module Neo4j
  module Driver
    module PackStream
      # PackStream Packer - serializes Ruby objects to PackStream binary format
      # Based on https://neo4j.com/docs/bolt/current/packstream/
      class Packer
        include Markers

        def initialize
          @buffer = String.new(encoding: Encoding::BINARY)
        end

        def pack(value)
          case value
          when nil
            pack_null
          when true, false
            pack_boolean(value)
          when Integer
            pack_integer(value)
          when Float
            pack_float(value)
          when String
            # Pack binary strings as BYTES, text strings as STRING
            value.encoding == Encoding::BINARY ? pack_bytes(value) : pack_string(value)
          when Symbol
            pack_string(value.to_s)
          when Hash
            # Check Hash before Enumerable since Hash is also Enumerable
            pack_map(value)
          when Types::Node, Types::Relationship, Types::Path
            # Graph types are not valid query parameters. Reject before the
            # Enumerable branch since Path includes Enumerable.
            raise Exceptions::ClientException, "Unable to convert #{value.class} to Neo4j Value."
          when Array, Set, Range
            # Known sized collections — pack_list uses #size, which is O(1) here.
            pack_list(value)
          when Enumerable
            # Generic Enumerable (lazy enumerators, custom collections) — materialise
            # so #size is well-defined.
            pack_list(value.to_a)
          when ::DateTime, ::Time
            # Check DateTime before Date — DateTime < Date in Ruby, so the
            # Date branch would match first and pack away the time component.
            pack_datetime(value)
          when ::Date
            # Pack Ruby Date as Neo4j Date structure
            pack_date(value)
          when defined?(Types::LocalDateTime) && Types::LocalDateTime
            # Pack Types::LocalDateTime as Neo4j LocalDateTime (without timezone)
            pack_local_datetime(value)
          when defined?(Types::LocalTime) && Types::LocalTime
            pack_local_time(value)
          when defined?(Types::Time) && Types::Time
            pack_time(value)
          when defined?(Types::Point) && Types::Point
            pack_point(value)
          when defined?(Types::Duration) && Types::Duration
            pack_duration(value)
          else
            raise Exceptions::ClientException, "Unable to convert #{value.class} to Neo4j Value."
          end
          self
        end

        # Serialise a Bolt protocol message (a PackStream::Structure) onto the buffer.
        # Distinct from #pack so the user-value path doesn't carry knowledge of
        # the wire-level Structure type.
        def pack_message(structure)
          pack_structure(structure)
          self
        end

        def bytes
          @buffer
        end

        def reset
          @buffer.clear
          self
        end

        private

        def pack_null
          @buffer << [NULL].pack('C')
        end

        def pack_boolean(value)
          @buffer << [value ? TRUE : FALSE].pack('C')
        end

        def pack_integer(value)
          if value >= -16 && value <= 127
            # TINY_INT: -16 to +127
            @buffer << [value].pack('c')
          elsif value >= -128 && value <= 127
            @buffer << [INT_8, value].pack('Cc')
          elsif value >= -32_768 && value <= 32_767
            @buffer << [INT_16, value].pack('Cs>')
          elsif value >= -2_147_483_648 && value <= 2_147_483_647
            @buffer << [INT_32, value].pack('Cl>')
          elsif value >= -9_223_372_036_854_775_808 && value <= 9_223_372_036_854_775_807
            @buffer << [INT_64, value].pack('Cq>')
          else
            raise ArgumentError, "Integer value out of range: #{value}"
          end
        end

        def pack_float(value)
          @buffer << [FLOAT_64].pack('C')
          @buffer << [value].pack('G')
        end

        def pack_string(value)
          bytes = value.encode(Encoding::UTF_8).b
          size = bytes.bytesize

          if size < 16
            @buffer << [TINY_STRING | size].pack('C')
          elsif size <= 255
            @buffer << [STRING_8, size].pack('CC')
          elsif size <= 65_535
            @buffer << [STRING_16, size].pack('CS>')
          elsif size <= 2_147_483_647
            @buffer << [STRING_32, size].pack('CL>')
          else
            raise ArgumentError, "String too long: #{size} bytes"
          end

          @buffer << bytes
        end

        def pack_bytes(value)
          size = value.bytesize

          if size <= 255
            @buffer << [BYTES_8, size].pack('CC')
          elsif size <= 65_535
            @buffer << [BYTES_16, size].pack('CS>')
          elsif size <= 2_147_483_647
            @buffer << [BYTES_32, size].pack('CL>')
          else
            raise ArgumentError, "Bytes too long: #{size} bytes"
          end

          @buffer << value
        end

        def pack_list(value)
          size = value.size

          if size < 16
            @buffer << [TINY_LIST | size].pack('C')
          elsif size <= 255
            @buffer << [LIST_8, size].pack('CC')
          elsif size <= 65_535
            @buffer << [LIST_16, size].pack('CS>')
          elsif size <= 2_147_483_647
            @buffer << [LIST_32, size].pack('CL>')
          else
            raise ArgumentError, "List too long: #{size} items"
          end

          value.each(&method(:pack))
        end

        def pack_map(value)
          size = value.size

          if size < 16
            @buffer << [TINY_MAP | size].pack('C')
          elsif size <= 255
            @buffer << [MAP_8, size].pack('CC')
          elsif size <= 65_535
            @buffer << [MAP_16, size].pack('CS>')
          elsif size <= 2_147_483_647
            @buffer << [MAP_32, size].pack('CL>')
          else
            raise ArgumentError, "Map too long: #{size} entries"
          end

          value.each do |key, val|
            pack(key.to_s)
            pack(val)
          end
        end

        def pack_structure(value)
          size = value.fields.size

          if size < 16
            @buffer << [TINY_STRUCT | size].pack('C')
          elsif size <= 255
            @buffer << [STRUCT_8, size].pack('CC')
          elsif size <= 65_535
            @buffer << [STRUCT_16, size].pack('CS>')
          else
            raise ArgumentError, "Structure too large: #{size} fields"
          end

          @buffer << [value.signature].pack('C')
          value.fields.each { |field| pack(field) }
        end

        def pack_date(value)
          days = (value - ::Date.new(1970, 1, 1)).to_i
          # Date structure: signature 0x44, 1 field (days)
          @buffer << [TINY_STRUCT | 1, 0x44].pack('CC')
          pack_integer(days)
        end

        def pack_datetime(value)
          # Normalise DateTime to Time so we can rely on Time's API (nsec,
          # utc_offset, to_i) uniformly.
          value = value.to_time if value.is_a?(::DateTime)

          tz_offset = value.utc_offset
          nanoseconds = value.nsec
          # Both 0x46 and 0x66 use LOCAL seconds encoding (wall-clock time
          # treated as if it were UTC); see the matching hydration handlers.
          epoch_seconds = value.to_i + tz_offset
          zone_name = named_zone_for(value)

          if zone_name
            # ZonedDateTime: signature 0x66, fields [seconds, nanos, tz_name]
            @buffer << [TINY_STRUCT | 3, 0x66].pack('CC')
            pack_integer(epoch_seconds)
            pack_integer(nanoseconds)
            pack_string(zone_name)
          else
            # DateTime with offset: signature 0x46, fields [seconds, nanos, tz_offset]
            @buffer << [TINY_STRUCT | 3, 0x46].pack('CC')
            pack_integer(epoch_seconds)
            pack_integer(nanoseconds)
            pack_integer(tz_offset)
          end
        end

        # Return the IANA zone name for a TimeWithZone-like value when it has
        # one, otherwise nil (so the caller falls back to offset-only 0x46).
        # Offset-shaped names like "+07:00" or "-05:00" don't round-trip
        # through Neo4j's zoned DateTime and are treated as nil.
        def named_zone_for(value)
          return nil unless value.respond_to?(:time_zone)

          tz = value.time_zone
          name = tz.respond_to?(:name) ? tz.name : nil
          return nil if name.nil? || name.empty? || name.match?(/\A[+-]?\d/)

          name
        end

        def pack_local_datetime(value)
          # LocalDateTime structure: signature 0x64, 2 fields (seconds, nanos)
          @buffer << [TINY_STRUCT | 2, 0x64].pack('CC')
          pack_integer(value.epoch_seconds)
          pack_integer(value.nanoseconds)
        end

        def pack_time(value)
          # Time structure: signature 0x54, 2 fields (nanos, tz_offset)
          @buffer << [TINY_STRUCT | 2, 0x54].pack('CC')
          pack_integer(value.nanoseconds)
          pack_integer(value.tz_offset_seconds)
        end

        def pack_local_time(value)
          # LocalTime structure: signature 0x74, 1 field (nanos)
          @buffer << [TINY_STRUCT | 1, 0x74].pack('CC')
          pack_integer(value.nanoseconds)
        end

        def pack_point(value)
          if value.z.nil?
            # Point2D: signature 0x58, 3 fields (srid, x, y)
            @buffer << [TINY_STRUCT | 3, 0x58].pack('CC')
            pack_integer(value.srid)
            pack_float(value.x)
            pack_float(value.y)
          else
            # Point3D: signature 0x59, 4 fields (srid, x, y, z)
            @buffer << [TINY_STRUCT | 4, 0x59].pack('CC')
            pack_integer(value.srid)
            pack_float(value.x)
            pack_float(value.y)
            pack_float(value.z)
          end
        end

        def pack_duration(value)
          # Duration: signature 0x45, 4 fields (months, days, seconds, nanoseconds)
          @buffer << [TINY_STRUCT | 4, 0x45].pack('CC')
          pack_integer(value.months)
          pack_integer(value.days)
          pack_integer(value.seconds)
          pack_integer(value.nanoseconds)
        end
      end
    end
  end
end
