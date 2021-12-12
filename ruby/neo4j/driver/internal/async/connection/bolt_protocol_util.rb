module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class BoltProtocolUtil
          BOLT_MAGIC_PREAMBLE = 0x6060B017
          # TODO: convert
          NO_PROTOCOL_VERSION = org.neo4j.driver.internal.messaging.BoltProtocolVersion.new(0, 0)
          CHUNK_HEADER_SIZE_BYTES = 2
          DEFAULT_MAX_OUTBOUND_CHUNK_SIZE_BYTES = java.lang.Short::MAX_VALUE / 2
          HANDSHAKE_BUF = org.neo4j.driver.internal.shaded.io.netty.buffer.Unpooled.unreleasable_buffer(org.neo4j.driver.internal.shaded.io.netty.buffer.Unpooled.copyInt(
            BOLT_MAGIC_PREAMBLE,
            # TODO: convert
            org.neo4j.driver.internal.messaging.v44.BoltProtocolV44::VERSION.to_int_range(org.neo4j.driver.internal.messaging.v42.BoltProtocolV42::VERSION),
            # TODO: convert
            org.neo4j.driver.internal.messaging.v41.BoltProtocolV41::VERSION.to_int,
            # TODO: convert
            org.neo4j.driver.internal.messaging.v4.BoltProtocolV4::VERSION.to_int,
            # TODO: convert
            org.neo4j.driver.internal.messaging.v3.BoltProtocolV3::VERSION.to_int
          )).freeze

          class << self
            def handshake_buf
              HANDSHAKE_BUF.duplicate
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
              buf = handshake_buf
              [buf.read_int.to_s(16), buf.read_int, buf.read_int, buf.read_int, buf.read_int]
            end
          end

          HANDSHAKE_STRING = create_handshake_string
        end
      end
    end
  end
end
