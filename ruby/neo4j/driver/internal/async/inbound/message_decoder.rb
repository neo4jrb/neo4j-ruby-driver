module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class MessageDecoder #<  org.neo4j.driver.internal.shaded.io.netty.handler.codec.ByteToMessageDecoder
          class << self
            def determine_default_cumulator
              value = ENV['message_decoder_cumulator']
              # 'merge' ==  value ? org.neo4j.driver.internal.shaded.io.netty.handler.codec.ByteToMessageDecoder::MERGE_CUMULATOR : org.neo4j.driver.internal.shaded.io.netty.handler.codec.ByteToMessageDecoder::COMPOSITE_CUMULATOR
            end
          end

          DEFAULT_CUMULATOR = determine_default_cumulator

          def initialize
            set_cumulator(DEFAULT_CUMULATOR)
          end

          def channel_read(ctx, msg)
            if msg.is_a?(org.neo4j.driver.internal.shaded.io.netty.buffer.ByteBuf)

              # on every read check if input buffer is empty or not
              # if it is empty then it's a message boundary and full message is in the buffer
              @read_message_boundary = msg.readable_bytes == 0
            end

            org.neo4j.driver.internal.shaded.io.netty.handler.codec.ByteToMessageDecoder.channel_read(ctx, msg)
          end

          def decode(ctx, inward, out)
            if @read_message_boundary

              # now we have a complete message in the input buffer

              # increment ref count of the buffer and create it's duplicate that shares the content
              # duplicate will be the output of this decoded and input for the next one
              message_buf = inward.retained_duplicate

              # signal that whole message was read by making input buffer seem like it was fully read/consumed
              inward.reader_index(inward.readable_bytes)

              # pass the full message to the next handler in the pipeline
              out.add(message_buf)
              @read_message_boundary = false
            end
          end
        end
      end
    end
  end
end
