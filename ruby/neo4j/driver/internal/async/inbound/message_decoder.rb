module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class MessageDecoder
          DEFAULT_CUMULATOR = determine_default_cumulator
          attr_accessor :read_message_boundary

          def initialize
            set_cumulator(DEFAULT_CUMULATOR)
            @read_message_boundary = nil
          end

          def channel_read(ctx, msg)
            if msg.kind_of?(io.netty.buffer.ByteBuf)

              # on every read check if input buffer is empty or not
              # if it is empty then it's a message boundary and full message is in the buffer
              read_message_boundary = msg.readable_bytes == 0
            end

            io.netty.handler.codec.ByteToMessageDecoder.channel_read(ctx, msg)
          end

          def decode(ctx, in, out)
            if read_message_boundary

              # now we have a complete message in the input buffer

              # increment ref count of the buffer and create it's duplicate that shares the content
              # duplicate will be the output of this decoded and input for the next one
              message_buf = in.retained_duplicate

              # signal that whole message was read by making input buffer seem like it was fully read/consumed
              in.read_index(in.readable_bytes)

              # pass the full message to the next handler in the pipeline
              out.add(message_buf)
              read_message_boundary = false
            end

          end

          class << self
            def determine_default_cumulator
              value = java.lang.System.get_property('message_decoder_cumulator', '')

              return MERGE_CUMULATOR if 'merge' == value

              return COMPOSITE_CUMULATOR
            end
          end
        end
      end
    end
  end
end
