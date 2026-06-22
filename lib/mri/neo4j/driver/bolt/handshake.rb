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

        # First four bytes of an HTTP response ("HTTP") read as a
        # big-endian int — a server speaking HTTP on the Bolt port.
        HTTP_REPLY = 0x4854_5450

        # Slot 1 advertises "I speak HandshakeManifestV1". Decodes as
        # BoltVersion(major=255, minor=1); servers that don't understand
        # the sentinel ignore it and pick from slots 2-4 instead.
        MANIFEST_SENTINEL = 0x00_00_01_FF

        # Range encoding: [reserved=0, range=N, minor, major]. Each
        # slot covers `major.minor` down to `major.(minor-N)`. We
        # advertise 5.0–5.8 (slot 2), 4.2–4.4 (slot 3) and 3.0 (slot 4).
        # Bolt 3.0 is fully wired now (Protocol::V3: PULL_ALL /
        # DISCARD_ALL, single-DB, no routing in HELLO).
        SLOTS = [
          MANIFEST_SENTINEL,
          0x00_08_08_05,  # 5.0–5.8
          0x00_02_04_04,  # 4.2–4.4
          0x00_00_00_03   # 3.0
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
          BoltVersion::V4_2,
          BoltVersion::V3_0
        ].freeze

        # `deadline` (monotonic) bounds the negotiation reads so a server that
        # stalls the magic-byte exchange can't outlast the acquisition timeout.
        # We read via wait_readable + read_nonblock rather than read(n)+IO#timeout
        # because IO#timeout is honored for read() only on CRuby, not JRuby —
        # wait_readable times out on both, so the bound works on every flavor.
        def initialize(socket, deadline: nil)
          @socket = socket
          @deadline = deadline
        end

        # Run the handshake to completion. Returns the negotiated
        # version as a 32-bit int in the wire's slot encoding
        # ([reserved, range=0, minor, major]).
        # Sanity cap on the manifest's range-count varint. The varint
        # itself is bounded to 63 usable bits but a server (malicious
        # or buggy) could still ask us to allocate billions of slots.
        # 256 is comfortably above the realistic upper bound (Java
        # currently advertises ~5 ranges) and well below anything
        # that'd hurt to allocate.
        MAX_MANIFEST_RANGES = 256

        def negotiate
          @socket.write(MAGIC_PREAMBLE)
          SLOTS.each { |slot| @socket.write([slot].pack('L>')) }
          @socket.flush

          server_reply = read_int32!('Server closed the connection during handshake')
          raise Exceptions::ServiceUnavailableException,
                'Server does not support any of the proposed Bolt versions' if server_reply.zero?

          # An HTTP server on the Bolt port replies with an HTTP status
          # line; its first four bytes spell "HTTP". Mirror Java's helpful
          # error instead of reporting a bogus protocol version.
          raise Exceptions::ClientException,
                'Server responded HTTP. Make sure you are not trying to connect to the http ' \
                'endpoint (HTTP defaults to port 7474 whereas BOLT defaults to port 7687)' if server_reply == HTTP_REPLY

          server_reply == MANIFEST_SENTINEL ? negotiate_manifest : server_reply
        end

        private

        # The manifest path: read the server's supported-version list
        # and capabilities, pick the highest version we know, write
        # back our choice + an empty-capabilities varlong.
        def negotiate_manifest
          count = read_varint
          if count > MAX_MANIFEST_RANGES
            raise Exceptions::ServiceUnavailableException,
                  "Server's manifest range count #{count} exceeds the #{MAX_MANIFEST_RANGES} cap"
          end

          ranges = Array.new(count) { read_int32!('Connection closed mid-manifest while reading version ranges') }
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
          bytes = read_fully(4)
          bytes ? bytes.unpack1('L>') : nil
        end

        # Read exactly n bytes, bounded by @deadline. Returns the bytes, or nil
        # on EOF / deadline (callers turn nil into the right handshake error).
        # wait_readable yields under a Fiber scheduler and times out on every
        # Ruby (unlike read()+IO#timeout, which only times out on CRuby).
        def read_fully(n)
          buf = String.new(encoding: Encoding::BINARY)
          while buf.bytesize < n
            case (chunk = @socket.read_nonblock(n - buf.bytesize, exception: false))
            when :wait_readable then (@socket.wait_readable(remaining_budget) || return)
            when :wait_writable then (@socket.wait_writable(remaining_budget) || return)
            when nil then return
            else buf << chunk
            end
          end
          buf
        end

        def remaining_budget
          return nil unless @deadline

          [@deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0.0].max
        end

        # Same as read_int32 but raises a ServiceUnavailableException
        # on short read instead of returning nil. Use this whenever a
        # nil result would propagate into bitmasks / arithmetic and
        # crash with a less helpful TypeError downstream.
        def read_int32!(message)
          read_int32 || raise(Exceptions::ServiceUnavailableException, message)
        end

        # LEB128 unsigned varint / varlong. 7 data bits per byte, MSB
        # is the continuation flag. Java caps at 9 bytes (63 usable
        # bits) and so do we — anything wider is a malformed peer.
        def read_varint
          value = 0
          shift = 0
          9.times do
            byte = read_fully(1)&.unpack1('C')
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
