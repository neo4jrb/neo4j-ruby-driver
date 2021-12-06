module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class InboundMessageHandler < io.netty.channel.SimpleChannelInboundHandler
          attr_accessor :message_dispatcher, :log
          attr_reader :input, :reader, :logging

          def initialize(message_format, logging)
            @input = ByteBufInput.new
            @reader = message_format.new_reader(input)
            @logging = logging
          end

          def handler_added(ctx)
            message_dispatcher = java.util.Objects.require_non_null(connection.ChannelAttributes.message_dispatcher(ctx.channel))
            log = Logging::ChannelActivityLogger.new(ctx.channel, logging, get_class)
          end

          def handler_removed(ctx)
            message_dispatcher = nil
            log = nil
          end

          def channel_read0(ctx, msg)
            if message_dispatcher.fatal_error_occurred
              return log.warn( "Message ignored because of the previous fatal error. Channel will be closed. Message:\n#{io.netty.buffer.ByteBufUtil.hex_dump(msg)}")
            end

            log.trace( "S: #{io.netty.buffer.ByteBufUtil.hex_dump(msg)}") if log.is_trace_enabled?

            input.start(msg)

            begin
              reader.read(message_dispatcher)
            rescue Exception => e
              io.netty.handler.codec.DecoderException.new("Failed to read inbound message:\n#{io.netty.buffer.ByteBufUtil.hex_dump(msg)}\n", error)
            ensure
              input.stop
            end
          end
        end
      end
    end
  end
end
