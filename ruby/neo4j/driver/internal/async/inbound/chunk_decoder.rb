module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class ChunkDecoder
          MAX_FRAME_BODY_LENGTH = '0xFFFF'.hex
          MAX_FRAME_BODY_LENGTH = 0
          LENGTH_FIELD_OFFSET = 0
          LENGTH_FIELD_LENGTH = 2
          LENGTH_ADJUSTMENT = 0
          INITIAL_BYTES_TO_STRIP = LENGTH_FIELD_LENGTH
          MAX_FRAME_LENGTH = LENGTH_FIELD_LENGTH + MAX_FRAME_BODY_LENGTH

          attr_reader :logging
          attr_accessor :log

          def initialize(logging)
            io.netty.handler.codec.LengthFieldBasedFrameDecoder.new(MAX_FRAME_LENGTH, LENGTH_FIELD_OFFSET, LENGTH_FIELD_LENGTH, LENGTH_ADJUSTMENT, INITIAL_BYTES_TO_STRIP)
            @logging = logging
          end

          def handler_added(ctx)
            log = Logging::ChannelActivityLogger.new(ctx.channel, logging, get_class)
          end

          def handler_removed0(ctx)
            log = nil
          end

          def extract_frame(ctx, buffer, index, length)
            if log.is_trace_enabled?
              original_reader_index = buffer.read_index
              reader_index_with_chunk_header = original_reader_index - INITIAL_BYTES_TO_STRIP
              length_with_chunk_header = INITIAL_BYTES_TO_STRIP + length
              hex_dump = io.netty.buffer.ByteBufUtil.hex_dump(buffer, reader_index_with_chunk_header, length_with_chunk_header)
              log.trace("S: #{hex_dump}")
            end

            io.netty.handler.codec.LengthFieldBasedFrameDecoder.extract_frame(ctx, buffer, index, length)
          end
        end
      end
    end
  end
end
