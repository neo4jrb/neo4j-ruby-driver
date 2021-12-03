
# Copyright (c) "Neo4j"
# Neo4j Sweden AB [http://neo4j.com]

# This file is part of Neo4j.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
              [buf.read_int.to_s(16), buf.read_int, buf.read_int, buf.read_int, buf.read_int]
            end
          end
        end
      end
    end
  end
end
