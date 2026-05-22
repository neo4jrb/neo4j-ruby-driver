# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Bolt handshake negotiation. Two paths share the same 20-byte
      # preamble (magic + four 4-byte slots, slot 1 = manifest sentinel):
      #
      #   Legacy: server replies with one of the proposed versions
      #           (4 bytes, big-endian). Pre-5.7 servers always take
      #           this path because they don't speak manifest.
      #
      #   Manifest v1: server replies with the sentinel 0x000001FF,
      #           then sends a varint count + N×4-byte version ranges +
      #           a varlong capabilities mask. Client picks the highest
      #           version it supports and writes back the chosen
      #           version (4 bytes) + a varlong of capabilities
      #           (currently always 0 — we negotiate no capabilities).
      #
      # Mirrors `BoltProtocolUtil` / `HandshakeHandler` / `ManifestHandlerV1`
      # in neo4j-bolt-connection-java.
      class Handshake
        MAGIC_PREAMBLE = "\x60\x60\xB0\x17".b

        # Slot 1 advertises "I speak HandshakeManifestV1". Decodes as
        # BoltVersion(major=255, minor=1); servers that don't understand
        # the sentinel ignore it and pick from slots 2-4 instead.
        MANIFEST_SENTINEL = 0x00_00_01_FF

        # Range encoding: [reserved=0, range=N, minor, major]. Each
        # slot covers `major.minor` down to `major.(minor-N)`. We
        # advertise 5.0–5.8 (slot 2) and 4.2–4.4 (slot 3). Slot 4 is
        # unused (zero). We don't advertise Bolt 3.0: PULL_ALL /
        # DISCARD_ALL / no-multi-DB / no-routing aren't wired and a
        # crash on dispatch is worse than refusing the handshake
        # outright; 3.0-only servers (Neo4j 3.4 / 3.5) are EOL.
        SLOTS = [
          MANIFEST_SENTINEL,
          0x00_08_08_05,  # 5.0–5.8
          0x00_02_04_04,  # 4.2–4.4
          0x00_00_00_00   # unused
        ].freeze

        # Versions we'd accept from a manifest, highest-preference first.
        # Used to pick a winner from whatever the server advertises.
        SUPPORTED_VERSIONS = [
          BoltVersion::V6_0,
          BoltVersion::V5_8,
          BoltVersion::V5_7,
          BoltVersion::V5_6,
          BoltVersion::V5_5,
          BoltVersion::V5_4,
          BoltVersion::V5_3,
          BoltVersion::V5_2,
          BoltVersion::V5_1,
          BoltVersion::V5_0,
          BoltVersion::V4_4,
          BoltVersion::V4_3,
          BoltVersion::V4_2
        ].freeze

        def initialize(socket)
          @socket = socket
        end

        # Run the handshake to completion. Returns the negotiated
        # version as a 32-bit int in the wire's slot encoding
        # ([reserved, range=0, minor, major]).
        def negotiate
          @socket.write(MAGIC_PREAMBLE)
          SLOTS.each { |slot| @socket.write([slot].pack('L>')) }
          @socket.flush

          server_reply = read_int32
          raise Exceptions::ServiceUnavailableException,
                'Server closed the connection during handshake' if server_reply.nil?
          raise Exceptions::ServiceUnavailableException,
                'Server does not support any of the proposed Bolt versions' if server_reply.zero?

          server_reply == MANIFEST_SENTINEL ? negotiate_manifest : server_reply
        end

        private

        # The manifest path: read the server's supported-version list
        # and capabilities, pick the highest version we know, write
        # back our choice + an empty-capabilities varlong.
        def negotiate_manifest
          ranges = read_varint.times.map { read_int32 }
          read_varlong # server capabilities — consume but ignore (no caps requested)

          chosen = pick_version(ranges)
          unless chosen
            # Tell the server we couldn't agree (4 bytes of zero +
            # zero-varlong cap), then bail. Same shape as Java's
            # ManifestHandlerV1 no-match path.
            @socket.write([0].pack('L>'))
            write_varlong(0)
            @socket.flush
            raise Exceptions::ServiceUnavailableException,
                  "Server's manifest offered no Bolt version we support"
          end

          @socket.write([chosen.to_wire].pack('L>'))
          # We don't request any capabilities yet (BoltCapability.FABRIC
          # is the only one Java defines, and we don't use Fabric).
          write_varlong(0)
          @socket.flush

          chosen.to_wire
        end

        # The server's version list comes as raw ints encoded
        # `(minor_count << 16) | (minor << 8) | major`. Walk our
        # preference list and pick the first that any advertised range
        # covers.
        def pick_version(ranges)
          SUPPORTED_VERSIONS.find { |v| ranges.any? { |range_int| range_covers?(range_int, v) } }
        end

        def range_covers?(range_int, version)
          major = range_int & 0xFF
          top_minor = (range_int >> 8) & 0xFF
          count = (range_int >> 16) & 0xFF
          return false unless version.major == major

          version.minor <= top_minor && version.minor >= top_minor - count
        end

        def read_int32
          bytes = @socket.read(4)
          bytes && bytes.bytesize == 4 ? bytes.unpack1('L>') : nil
        end

        # LEB128 unsigned varint / varlong. 7 data bits per byte, MSB
        # is the continuation flag. Java caps at 9 bytes (63 usable
        # bits) and so do we — anything wider is a malformed peer.
        def read_varint
          value = 0
          shift = 0
          9.times do
            byte = @socket.read(1)&.unpack1('C')
            raise IOError, 'Unexpected end of stream while reading varint' if byte.nil?

            value |= (byte & 0x7F) << shift
            return value if byte & 0x80 == 0

            shift += 7
          end
          raise Exceptions::ServiceUnavailableException, 'Varint overflow during handshake'
        end
        alias read_varlong read_varint

        def write_varlong(value)
          # do/while so zero still emits a single 0x00 byte (matches
          # Java's writeVarLong).
          loop do
            byte = value & 0x7F
            value >>= 7
            if value.zero?
              @socket.write([byte].pack('C'))
              break
            else
              @socket.write([byte | 0x80].pack('C'))
            end
          end
        end
      end
    end
  end
end
