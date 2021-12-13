module Neo4j::Driver
  module Internal
    module Async
      module Outbound
        class OutboundMessageHandler
          NAME = self.new.class

          attr_accessor :output, :writer, :logging, :log

          def initialize(message_format, logging)
            @output = ChunkAwareByteBufOutput.new
            @writer = message_format.new_writer(output)
            @logging = logging
          end

          def handler_added(ctx)
            log = Logging::ChannelActivityLogger.new(ctx.channel, logging, get_class)
          end

          def handler_removed(ctx)
            log = nil
          end

          def encode(ctx, msg, out)
            log.debug("C: #{ msg}")

            message_buf = ctx.alloc.io_buffer
            output.start(message_buf)
            begin
              writer.write(msg)
              output.stop
            rescue Exception => e
              output.stop
              # release buffer because it will not get added to the out list and no other handler is going to handle it
              message_buf.release
              io.netty.handler.codec.EncoderException.new("Failed to write outbound message: #{msg}", e)
            end

            log.trace( "C: #{io.netty.buffer.ByteBufUtil.hex_dump(message_buf)}") if log.is_trace_enabled?

            Connection::BoltProtocolUtil.write_message_boundary(message_buf)
            out.add(message_buf)
          end
        end
      end
    end
  end
end
