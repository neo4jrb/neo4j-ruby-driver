# frozen_string_literal: true

module Neo4j
  module Driver
    module PackStream
      # PackStream Unpacker - deserializes PackStream binary format to Ruby objects
      class Unpacker
        include Markers

        def initialize(io, protocol)
          @io = io
          @hydration_handlers = {}
          @protocol = protocol
        end

        def register_hydration_handler(signature, handler = nil, &block)
          @hydration_handlers[signature] = handler || block
        end

        def unpack
          marker_byte = read_bytes(1).unpack1('C')
          unpack_value(marker_byte)
        end

        # PackStream V2 UUID (Bolt 6.1+): 16 raw bytes (big-endian) after the
        # marker, rendered to the canonical hyphenated form for Types::UUID.
        # Called by Protocol::V61#unpack_uuid — earlier protocols reject the
        # marker instead, so this is only reached once 6.1 is negotiated.
        def unpack_uuid_value
          hex = read_bytes(16).unpack1('H*')
          Types::UUID.from_string(
            "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}")
        end

        # A ProtocolException (not a bare RuntimeError) so the failure reaches
        # the user as a DriverError. The wording carries "PackStream" and the
        # zero-padded marker byte — e.g. a UUID (0xE0) received before Bolt 6.1,
        # which Protocol::Base#unpack_uuid routes here. testkit's UUID-over-6.0
        # assertion greps the lowercased message for "unknown packstream" and
        # "e0", both of which this satisfies.
        def raise_unknown_marker(marker)
          raise Exceptions::ProtocolException,
                format('Unknown PackStream type marker: 0x%02x', marker)
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
          when UUID
            # A PackStream V2 type: only the negotiated protocol decides whether
            # the marker is known — V61 reads it, every earlier version rejects
            # it as an unknown marker.
            @protocol.unpack_uuid(self)
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
              raise_unknown_marker(marker)
            end
          end
        end

        def unpack_list(size) = Array.new(size) { unpack }

        def unpack_map(size)
          {}.tap { |map| size.times { map[unpack.to_sym] = unpack } }
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
