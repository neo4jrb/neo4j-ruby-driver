module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class BoltProtocolUtil
          BOLT_MAGIC_PREAMBLE = 0x6060B017
          NO_PROTOCOL_VERSION = Messaging::BoltProtocolVersion.new(0, 0)
          CHUNK_HEADER_SIZE_BYTES = 2
          DEFAULT_MAX_OUTBOUND_CHUNK_SIZE_BYTES = 2 ** 15 - 1
          HANDSHAKE = [
            BOLT_MAGIC_PREAMBLE,
            Messaging::V44::BoltProtocolV44::VERSION.to_int_range(Messaging::V42::BoltProtocolV42::VERSION),
            Messaging::V41::BoltProtocolV41::VERSION.to_int,
            Messaging::V4::BoltProtocolV4::VERSION.to_int,
            Messaging::V3::BoltProtocolV3::VERSION.to_int]
          HANDSHAKE_BUF = HANDSHAKE.pack('N*').freeze

          class << self
            def handshake_buf
              HANDSHAKE_BUF.dup
            end

            def handshake_string
              HANDSHAKE_STRING
            end

            def write_message_boundary(buf)
              buf.write_short(0)
            end

            def write_empty_chunk_header(buf)
              buf.write_short(0)
            end

            def write_chunk_header(buf, chunk_start_index, header_value)
              buf.set_short(chunk_start_index, header_value)
            end

            private

            def create_handshake_string
              "[0x#{HANDSHAKE.first.to_s(16)}, %s, %s, %s, %s]" % HANDSHAKE[1, 4]
            end
          end

          HANDSHAKE_STRING = create_handshake_string
        end
      end
    end
  end
end
