module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class BoltProtocolUtil
          BOLT_MAGIC_PREAMBLE = '0x6060B017'
          NO_PROTOCOL_VERSION = BoltProtocolVersion.new(0, 0)
          CHUNK_HEADER_SIZE_BYTES = 2
          DEFAULT_MAX_OUTBOUND_CHUNK_SIZE_BYTES = java.lang.Short.MAX_VALUE / 2
          HANDSHAKE_BUF = io.netty.buffer.Unpooled.unreleasable_buffer(io.netty.buffer.Unpooled.copyInt(
            BOLT_MAGIC_PREAMBLE,
            BoltProtocolV44::VERSION.to_int_range(BoltProtocolV42::VERSION),
            BoltProtocolV41::VERSION.to_int,
            BoltProtocolV4::VERSION.to_int,
            BoltProtocolV3::VERSION.to_int
            )).freeze
          HANDSHAKE_STRING = create_handshake_string

          class << self
            def handshake_buf
              HANDSHAKE_BUF.clone
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

            def create_hand_shake_string
              buf = handshake_buf
              return buf.read_int.to_s(16), buf.read_int, buf.read_int, buf.read_int, buf.read_int
            end
          end
        end
      end
    end
  end
end