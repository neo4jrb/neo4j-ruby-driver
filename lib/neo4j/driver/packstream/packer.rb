# frozen_string_literal: true

module Neo4j
  module Driver
    module PackStream
      # PackStream Packer - serializes Ruby objects to PackStream binary format
      # Based on https://neo4j.com/docs/bolt/current/packstream/
      class Packer
        TINY_STRING = 0x80
        TINY_LIST = 0x90
        TINY_MAP = 0xA0
        TINY_STRUCT = 0xB0

        NULL = 0xC0
        FLOAT_64 = 0xC1
        FALSE = 0xC2
        TRUE = 0xC3

        INT_8 = 0xC8
        INT_16 = 0xC9
        INT_32 = 0xCA
        INT_64 = 0xCB

        BYTES_8 = 0xCC
        BYTES_16 = 0xCD
        BYTES_32 = 0xCE

        STRING_8 = 0xD0
        STRING_16 = 0xD1
        STRING_32 = 0xD2

        LIST_8 = 0xD4
        LIST_16 = 0xD5
        LIST_32 = 0xD6

        MAP_8 = 0xD8
        MAP_16 = 0xD9
        MAP_32 = 0xDA

        STRUCT_8 = 0xDC
        STRUCT_16 = 0xDD

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
          when Enumerable
            # Handle all Enumerable types (Array, Set, Range, etc.)
            # Array#to_a returns self, so no performance penalty
            pack_list(value.to_a)
          when Structure
            pack_structure(value)
          when ::Date
            # Pack Ruby Date as Neo4j Date structure
            pack_date(value)
          when ::Time, ::DateTime
            # Pack Ruby Time/DateTime as Neo4j DateTime structure (with timezone)
            pack_datetime(value)
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
            raise ArgumentError, "Cannot pack value of type #{value.class}"
          end
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

          value.each { |item| pack(item) }
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
          # DateTime structure: signature 0x46, 3 fields (seconds, nanos, tz_offset)
          epoch_seconds = value.to_i
          nanoseconds = (value.to_f - epoch_seconds) * 1_000_000_000
          tz_offset = value.utc_offset

          @buffer << [TINY_STRUCT | 3, 0x46].pack('CC')
          pack_integer(epoch_seconds)
          pack_integer(nanoseconds.to_i)
          pack_integer(tz_offset)
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
