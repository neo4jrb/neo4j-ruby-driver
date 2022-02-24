module Neo4j::Driver
  module Internal
    module Packstream
      class PackStream
        TINY_STRING = 0x80
        TINY_LIST = 0x90
        TINY_MAP = 0xA0
        TINY_STRUCT = 0xB0
        NULL = 0xC0
        FLOAT_64 = 0xC1
        FALSE = 0xC2
        TRUE = 0xC3
        RESERVED_C4 = 0xC4
        RESERVED_C5 = 0xC5
        RESERVED_C6 = 0xC6
        RESERVED_C7 = 0xC7
        INT_8 = 0xC8
        INT_16 = 0xC9
        INT_32 = 0xCA
        INT_64 = 0xCB
        BYTES_8 = 0xCC
        BYTES_16 = 0xCD
        BYTES_32 = 0xCE
        RESERVED_CF = 0xCF
        STRING_8 = 0xD0
        STRING_16 = 0xD1
        STRING_32 = 0xD2
        RESERVED_D3 = 0xD3
        LIST_8 = 0xD4
        LIST_16 = 0xD5
        LIST_32 = 0xD6
        RESERVED_D7 = 0xD7
        MAP_8 = 0xD8
        MAP_16 = 0xD9
        MAP_32 = 0xDA
        RESERVED_DB = 0xDB
        STRUCT_8 = 0xDC
        STRUCT_16 = 0xDD
        RESERVED_DE = 0xDE
        RESERVED_DF = 0xDF
        RESERVED_E0 = 0xE0
        RESERVED_E1 = 0xE1
        RESERVED_E2 = 0xE2
        RESERVED_E3 = 0xE3
        RESERVED_E4 = 0xE4
        RESERVED_E5 = 0xE5
        RESERVED_E6 = 0xE6
        RESERVED_E7 = 0xE7
        RESERVED_E8 = 0xE8
        RESERVED_E9 = 0xE9
        RESERVED_EA = 0xEA
        RESERVED_EB = 0xEB
        RESERVED_EC = 0xEC
        RESERVED_ED = 0xED
        RESERVED_EE = 0xEE
        RESERVED_EF = 0xEF

        PLUS_2_TO_THE_31  = 2147483648
        PLUS_2_TO_THE_16  = 65536
        PLUS_2_TO_THE_15  = 32768
        PLUS_2_TO_THE_7   = 128
        MINUS_2_TO_THE_4  = -16
        MINUS_2_TO_THE_7  = -128
        MINUS_2_TO_THE_15 = -32768
        MINUS_2_TO_THE_31 = -2147483648

        EMPTY_STRING = ''
        EMPTY_BYTE_ARRAY = []
        UTF_8 = Encoding::UTF_8

        class Packer
          def initialize(out)
            @out = out
          end

          private def pack_raw(data)
            @out.write_bytes(data)
          end

          def pack_null
            @out.write_bytes(nil)
          end

          def pack(value)
            case value
            when TrueClass || FalseClass
              @out.write_byte(value ? TRUE : FALSE)
            when java.lang.Byte
              @out.write_byte(value)
            when Integer
              @out.write_byte(INT_16).write_int(value)
            when Float
              @out.write_byte(FLOAT_64).write_double(value)
            when String
              if value.nil?
                pack_null
              else
                utf8 = value.bytes(UTF_8)
                pack_string_header(utf8.length)
                pack_raw(utf8)
              end
            when Array
              if value.nil?
                pack_null
              else
                utf8 = value.bytes(UTF_8)
                pack_list_header(utf8.size)
                value.each{|value| pack(value) }
              end
            when Hash
              if value.nil?
                pack_null
              else
                utf8 = value.bytes(UTF_8)
                pack_map_header(utf8.size)
                value.keys.each do |key|
                  pack(key)
                  pack(value[key])
                end
              end
            else
              raise UnPackable, "Cannot pack object #{value}"
            end
          end

          def pack_bytes_header(size)
            if size <= java.lang.Byte::MAX_VALUE
              @out.write_byte(BYTES_8).write_byte(size)
            elsif size < PLUS_2_TO_THE_16
              @out.write_byte(BYTES_16).write_short(size)
            else
              @out.write_byte(BYTES_32).write_int(size)
            end
          end

          def pack_string_header(size)
            if size < 0x10
              @out.write_byte(TINY_STRING | size)
            elsif size <= java.lang.Byte::MAX_VALUE
              @out.write_byte(STRING_8).write_byte(size)
            elsif size < PLUS_2_TO_THE_16
              @out.write_byte(BYTES_16).write_short(size)
            else
              @out.write_byte(STRING_32).write_int(size)
            end
          end

          def pack_list_header(size)
            if size < 0x10
              @out.write_byte(TINY_LIST | size)
            elsif size <= java.lang.Byte::MAX_VALUE
              @out.write_byte(LIST_8).write_byte(size)
            elsif size < PLUS_2_TO_THE_16
              @out.write_byte(LIST_16).write_short(size)
            else
              @out.write_byte(LIST_32).write_int(size)
            end
          end

          def pack_map_header(size)
            if size < 0x10
              @out.write_byte(TINY_MAP | size)
            elsif size <= java.lang.Byte::MAX_VALUE
              @out.write_byte(MAP_8).write_byte(size)
            elsif size < PLUS_2_TO_THE_16
              @out.write_byte(MAP_16).write_short(size)
            else
              @out.write_byte(MAP_32).write_int(size)
            end
          end

          def pack_struct_header(size, signature)
            if size < 0x10
              @out.write_byte(TINY_STRUCT | size).write_byte(signature)
            elsif size <= java.lang.Byte::MAX_VALUE
              @out.write_byte(STRUCT_8).write_byte(size).write_byte(signature)
            elsif size < PLUS_2_TO_THE_16
              @out.write_byte(STRUCT_16).write_short(size).write_byte(signature)
            else
              raise Overflow, "Structures cannot have more than #{PLUS_2_TO_THE_16 - 1} fields"
            end
          end
        end

        class Unpacker
          def initialize(_in)
            @in = _in
          end

          def unpack_struct_header
            marker_byte = @in.read_byte
            marker_high_nibble = (marker_byte & 0xF0)
            marker_low_nibble = (marker_byte & 0x0F)

            return marker_low_nibble if marker_high_nibble == TINY_STRUCT

            case marker_byte
            when STRUCT_8
              unpack_u_int8
            when STRUCT_16
              unpack_u_int16
            else
              raise Unexpected, "Expected a struct, but got: #{marker_byte.to_s(16)}"
            end
          end

          def unpack_struct_signature
            @in.read_byte
          end

          def unpack_list_header
            marker_byte = @in.read_byte
            marker_high_nibble = (marker_byte & 0xF0)
            marker_low_nibble = (marker_byte & 0x0F)

            return marker_low_nibble if marker_high_nibble == TINY_LIST

            case marker_byte
            when LIST_8
              unpack_u_int8
            when LIST_16
              unpack_u_int16
            when LIST_32
              unpack_u_int32
            else
              raise Unexpected, "Expected a list, but got: #{(markerByte & 0xFF).to_s(16)}"
            end
          end

          def unpack_map_header
            marker_byte = @in.read_byte
            marker_high_nibble = (marker_byte & 0xF0)
            marker_low_nibble = (marker_byte & 0x0F)

            return marker_low_nibble if marker_high_nibble == TINY_MAP

            case marker_byte
            when MAP_8
              unpack_u_int8
            when MAP_16
              unpack_u_int16
            when MAP_32
              unpack_u_int32
            else
              raise Unexpected, "Expected a map, but got: #{marker_byte.to_s(16)}"
            end
          end

          def unpack_long
            marker_byte = @in.read_byte

            return marker_byte if marker_byte >= MINUS_2_TO_THE_4

            case marker_byte
            when INT_8
              @in.read_byte
            when INT_16
              @in.read_short
            when INT_32
              @in.read_int
            when INT_64
              @in.read_long
            else
              raise Unexpected, "Expected a integer, but got: #{marker_byte.to_s(16)}"
            end
          end

          def unpack_double
            marker_byte = @in.read_byte

            return @in.read_double if marker_byte == FLOAT_64

            raise Unexpected, "Expected a double, but got: #{marker_byte.to_s(16)}"
          end

          def unpack_bytes
            marker_byte = @in.read_byte

            case marker_byte
            when BYTES_8
              unpack_raw_bytes(unpack_u_int8)
            when BYTES_16
              unpack_raw_bytes(unpack_u_int16)
            when BYTES_32
              size = unpack_u_int32

              return unpack_raw_bytes(size) if size <= java.lang.Integer::MAX_VALUE

              raise Overflow, 'BYTES_32 too long for Java'
            else
              raise Unexpected, "Expected a bytes, but got: #{(markerByte & 0xFF).to_s(16)}"
            end
          end

          def unpack_string
            marker_byte = @in.read_byte

            return EMPTY_STRING if marker_byte == TINY_STRING # Note no mask, so we compare to 0x80

            unpack_utf8(markerByte).encode(UTF_8)
          end

          # This may seem confusing. This method exists to move forward the internal pointer when encountering
          # a null value. The idiomatic usage would be someone using {@link #peekNextType()} to detect a null type,
          # and then this method to "skip past it".
          # @return null
          # @throws IOException if the unpacked value was not null
          def unpack_null
            marker_byte = @in.read_byte

            unless marker_byte.nil?
              raise Unexpected, "Expected a null, but got: 0x#{(markerByte & 0xFF).to_s(16)}"
            end

            nil
          end

          private def unpack_utf8(marker_byte)
            marker_high_nibble = (marker_byte & 0xF0)
            marker_low_nibble = (marker_byte & 0x0F)

            case marker_byte
            when STRING_8
              unpack_raw_bytes(unpack_u_int8)
            when STRING_16
              unpack_raw_bytes(unpack_u_int16)
            when STRING_32
              size = unpack_u_int32

              return unpack_raw_bytes(size) if size <= java.lang.Integer::MAX_VALUE

              raise Overflow, 'STRING_32 too long for Java'
            else
              raise Unexpected, "Expected a string, but got: 0x#{(markerByte & 0xFF).to_s(16)}"
            end
          end

          def unpack_boolean
            marker_byte = @in.read_byte

            case marker_byte
            when TRUE
              true
            when FALSE
              false
            else
              raise Unexpected, "Expected a boolean, but got: 0x#{(markerByte & 0xFF).to_s(16)}"
            end
          end

          private def unpack_u_int8
            @in.read_byte & 0xFF
          end

          private def unpack_u_int16
            @in.read_short & 0xFFFF
          end

          private def unpack_u_int32
            @in.read_int & 0xFFFFFFFF
          end

          private def unpack_raw_bytes(size)
            return EMPTY_BYTE_ARRAY if size == 0

            heap_buffer = []
            @in.read_bytes(heap_buffer, 0, heap_buffer.length)
            heap_buffer
          end

          def peek_next_type
            marker_byte = @in.peek_byte
            marker_high_nibble = (marker_byte & 0xF0)

            case marker_high_nibble
            when TINY_STRING
              PackType::STRING
            when TINY_LIST
              PackType::LIST
            when TINY_MAP
              PackType::MAP
            when TINY_STRUCT
              PackType::STRUCT
            end

            case marker_byte
            when NULL
              PackType::NULL
            when TRUE
            when FALSE
              PackType::BOOLEAN
            when FLOAT_64
              PackType::FLOAT
            when BYTES_8
            when BYTES_16
            when BYTES_32
              PackType::BYTES
            when LIST_8
            when LIST_16
            when LIST_32
              PackType::LIST
            when LIST_8
            when LIST_16
            when LIST_32
              PackType::MAP
            when STRUCT_8
            when STRUCT_16
              PackType::STRUCT
            else
              PackType::INTEGER
            end
          end
        end

        class << self
          class PackStreamException < IOError
          end

          class EndOfStream < PackStreamException
          end

          class Overflow < PackStreamException
          end

          class Unexpected < PackStreamException
          end

          class UnPackable < PackStreamException
          end
        end
      end
    end
  end
end
