module Neo4j::Driver
  module Internal
    module Packstream
      module PackStream
        module Common
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
        end

        PLUS_2_TO_THE_63 = 2 ** 63
        PLUS_2_TO_THE_31 = 2147483648
        PLUS_2_TO_THE_16 = 65536
        PLUS_2_TO_THE_15 = 32768
        PLUS_2_TO_THE_8 = 256
        PLUS_2_TO_THE_7 = 128
        MINUS_2_TO_THE_4 = -16
        MINUS_2_TO_THE_7 = -128
        MINUS_2_TO_THE_15 = -32768
        MINUS_2_TO_THE_31 = -2147483648
        MINUS_2_TO_THE_63 = -2 ** 63

        module Packer
          include Common
          private def pack_raw(data)
            write(data)
          end

          def pack_null
            write_byte(NULL)
          end

          def pack(value)
            case value
            when nil
              pack_null
            when TrueClass
              write_byte(TRUE)
            when FalseClass
              write_byte(FALSE)
            when Integer
              pack_integer(value)
            when Float
              pack_float(value)
            when String
              case value.encoding
              when Encoding::BINARY
                pack_bytes(value)
              when Encoding::UTF_8
                pack_string(value)
              else
                pack_string(value.encode(Encoding::UTF_8))
              end
            when Symbol
              pack_string(value.to_s)
            when InternalPath
              unpackable(value)
            when Hash
              pack_map_header(value.size)
              value.each do |key, val|
                pack(key)
                pack(val)
              end
            when Enumerable
              value = value.to_a
              pack_list_header(value.size)
              value.each(&method(:pack))
            when Bookmark
              pack(value.values)
            else
              unpackable(value)
            end
          end

          private def unpackable(value)
            raise UnPackable, "Cannot pack object #{value}"
          end

          def pack_integer(value)
            if value >= MINUS_2_TO_THE_4 && value < PLUS_2_TO_THE_7
              write_byte(value)
            elsif value >= MINUS_2_TO_THE_7 && value < MINUS_2_TO_THE_4
              write_byte(INT_8).write_byte(value)
            elsif value >= MINUS_2_TO_THE_15 && value < PLUS_2_TO_THE_15
              write_byte(INT_16).write_short(value)
            elsif value >= MINUS_2_TO_THE_31 && value < PLUS_2_TO_THE_31
              write_byte(INT_32).write_int(value)
            elsif value >= MINUS_2_TO_THE_63 && value < PLUS_2_TO_THE_63
              write_byte(INT_64).write_long(value)
            else
              pack_string(value.to_s)
            end
          end

          def pack_float(value)
            write_byte(FLOAT_64).write_double(value)
          end

          private def pack_bytes(value)
            pack_bytes_header(value.bytesize)
            pack_raw(value)
          end

          private def pack_string(value)
            pack_string_header(value.bytesize)
            pack_raw(value)
          end

          def pack_bytes_header(size)
            if size < PLUS_2_TO_THE_8
              write_byte(BYTES_8).write_byte(size)
            elsif size < PLUS_2_TO_THE_16
              write_byte(BYTES_16).write_short(size)
            else
              write_byte(BYTES_32).write_int(size)
            end
          end

          def pack_string_header(size)
            if size < 0x10
              write_byte(TINY_STRING | size)
            elsif size < PLUS_2_TO_THE_8
              write_byte(STRING_8).write_byte(size)
            elsif size < PLUS_2_TO_THE_16
              write_byte(STRING_16).write_short(size)
            else
              write_byte(STRING_32).write_int(size)
            end
          end

          def pack_list_header(size)
            if size < 0x10
              write_byte(TINY_LIST | size)
            elsif size < PLUS_2_TO_THE_8
              write_byte(LIST_8).write_byte(size)
            elsif size < PLUS_2_TO_THE_16
              write_byte(LIST_16).write_short(size)
            else
              write_byte(LIST_32).write_int(size)
            end
          end

          def pack_map_header(size)
            if size < 0x10
              write_byte(TINY_MAP | size)
            elsif size < PLUS_2_TO_THE_8
              write_byte(MAP_8).write_byte(size)
            elsif size < PLUS_2_TO_THE_16
              write_byte(MAP_16).write_short(size)
            else
              write_byte(MAP_32).write_int(size)
            end
          end

          def pack_struct_header(size, signature)
            if size < 0x10
              write_byte(TINY_STRUCT | size).write_byte(signature)
            elsif size size < PLUS_2_TO_THE_8
              write_byte(STRUCT_8).write_byte(size).write_byte(signature)
            elsif size < PLUS_2_TO_THE_16
              write_byte(STRUCT_16).write_short(size).write_byte(signature)
            else
              raise Overflow, "Structures cannot have more than #{PLUS_2_TO_THE_16 - 1} fields"
            end
          end
        end

        module Unpacker
          include Common

          def unpack_struct_header
            marker_byte = read_byte
            marker_high_nibble = marker_byte & 0xF0
            marker_low_nibble = marker_byte & 0x0F

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
            read_byte
          end

          def unpack_list_header
            marker_byte = read_byte
            marker_high_nibble = marker_byte & 0xF0
            marker_low_nibble = marker_byte & 0x0F

            return marker_low_nibble if marker_high_nibble == TINY_LIST

            case marker_byte
            when LIST_8
              unpack_uint8
            when LIST_16
              unpack_uint16
            when LIST_32
              unpack_uint32
            else
              raise Unexpected, "Expected a list, but got: #{(markerByte & 0xFF).to_s(16)}"
            end
          end

          def unpack_map_header
            marker_byte = read_byte
            marker_high_nibble = marker_byte & 0xF0
            marker_low_nibble = marker_byte & 0x0F

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

          def unpack_long(marker_byte)
            return marker_byte if marker_byte >= MINUS_2_TO_THE_4
            marker_byte &= 0xFF
            case marker_byte
            when INT_8
              read_byte
            when INT_16
              read_short
            when INT_32
              read_int
            when INT_64
              read_long
            else
              raise Unexpected, "Expected an integer, but got: #{marker_byte.to_s(16)}"
            end
          end

          def unpack_double
            read_double
          end

          def unpack_bytes(size)
            read_exactly(size)
          end

          def unpack_string(size)
            read_exactly(size).force_encoding(Encoding::UTF_8)
          end
        end

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
