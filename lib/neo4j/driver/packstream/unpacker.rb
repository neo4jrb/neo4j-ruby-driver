# frozen_string_literal: true

module Neo4j
  module Driver
    module PackStream
      # PackStream Unpacker - deserializes PackStream binary format to Ruby objects
      class Unpacker
        include Markers

        def initialize(io)
          @io = io
          @hydration_handlers = {}
        end

        def register_hydration_handler(signature, handler = nil, &block)
          @hydration_handlers[signature] = handler || block
        end

        def unpack
          marker_byte = read_bytes(1).unpack1('C')
          unpack_value(marker_byte)
        end

        private

        def unpack_value(marker)
          case marker
          when NULL
            nil
          when FALSE
            false
          when TRUE
            true
          when FLOAT_64
            read_bytes(8).unpack1('G')
          when INT_8
            read_bytes(1).unpack1('c')
          when INT_16
            read_bytes(2).unpack1('s>')
          when INT_32
            read_bytes(4).unpack1('l>')
          when INT_64
            read_bytes(8).unpack1('q>')
          when 0xC8..0xCB
            # Already handled above, but needed for case coverage
            raise "Unexpected marker in unpack_value: #{marker}"
          when BYTES_8
            size = read_bytes(1).unpack1('C')
            read_bytes(size).force_encoding(Encoding::BINARY)
          when BYTES_16
            size = read_bytes(2).unpack1('S>')
            read_bytes(size).force_encoding(Encoding::BINARY)
          when BYTES_32
            size = read_bytes(4).unpack1('L>')
            read_bytes(size).force_encoding(Encoding::BINARY)
          when STRING_8
            size = read_bytes(1).unpack1('C')
            read_bytes(size).force_encoding(Encoding::UTF_8)
          when STRING_16
            size = read_bytes(2).unpack1('S>')
            read_bytes(size).force_encoding(Encoding::UTF_8)
          when STRING_32
            size = read_bytes(4).unpack1('L>')
            read_bytes(size).force_encoding(Encoding::UTF_8)
          when LIST_8
            size = read_bytes(1).unpack1('C')
            unpack_list(size)
          when LIST_16
            size = read_bytes(2).unpack1('S>')
            unpack_list(size)
          when LIST_32
            size = read_bytes(4).unpack1('L>')
            unpack_list(size)
          when MAP_8
            size = read_bytes(1).unpack1('C')
            unpack_map(size)
          when MAP_16
            size = read_bytes(2).unpack1('S>')
            unpack_map(size)
          when MAP_32
            size = read_bytes(4).unpack1('L>')
            unpack_map(size)
          when STRUCT_8
            size = read_bytes(1).unpack1('C')
            unpack_structure(size)
          when STRUCT_16
            size = read_bytes(2).unpack1('S>')
            unpack_structure(size)
          else
            # Check for TINY types
            if (marker & 0xF0) == TINY_STRING
              size = marker & 0x0F
              read_bytes(size).force_encoding(Encoding::UTF_8)
            elsif (marker & 0xF0) == TINY_LIST
              size = marker & 0x0F
              unpack_list(size)
            elsif (marker & 0xF0) == TINY_MAP
              size = marker & 0x0F
              unpack_map(size)
            elsif (marker & 0xF0) == TINY_STRUCT
              size = marker & 0x0F
              unpack_structure(size)
            elsif marker >= 0xF0 || marker <= 0x7F
              # TINY_INT range: -16 to 127
              # Values from 0xF0-0xFF represent -16 to -1
              # Values from 0x00-0x7F represent 0 to 127
              if marker >= 0xF0
                marker - 256 # Convert to negative
              else
                marker
              end
            else
              raise "Unknown marker: 0x#{marker.to_s(16)}"
            end
          end
        end

        def unpack_list(size) = Array.new(size) { unpack }

        def unpack_map(size)
          size.times.to_h { [unpack.to_sym, unpack] }
        end

        def unpack_structure(size)
          signature = read_bytes(1).unpack1('C')
          fields = Array.new(size) { unpack }
          handler = @hydration_handlers[signature] or
            raise "No hydration handler for PackStream structure signature 0x#{signature.to_s(16)}"

          handler.call(fields)
        end

        def read_bytes(n)
          data = @io.read(n)
          raise IOError, "Unexpected end of stream" if data.nil? || data.bytesize < n
          data
        end
      end
    end
  end
end
