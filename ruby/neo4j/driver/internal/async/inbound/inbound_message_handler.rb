module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class InboundMessageHandler #< org.neo4j.driver.internal.shaded.io.netty.channel.SimpleChannelInboundHandler
          def initialize(message_format, logger)
            @input = ByteBufInput.new
            @reader = message_format.new_reader(input)
            @logger = logger
          end

          def handler_added(ctx)
            @message_dispatcher = Validator::require_non_nil!(connection.ChannelAttributes.message_dispatcher(ctx.channel))
            @log = Logging::ChannelActivityLogger.new(ctx.channel, logger, self.class)
          end

          def handler_removed(_ctx)
            @message_dispatcher = nil
            @log = nil
          end

          def channel_read0(_ctx, msg)
            if message_dispatcher.fatal_error_occurred
              return @log.warn( "Message ignored because of the previous fatal error. Channel will be closed. Message:\n#{org.neo4j.driver.internal.shaded.io.netty.buffer.ByteBufUtil.hex_dump(msg)}")
            end

            @log.debug( "S: #{org.neo4j.driver.internal.shaded.io.netty.buffer.ByteBufUtil.hex_dump(msg)}") if @log.is_trace_enabled?

            @input.start(msg)
            begin
              @reader.read(@message_dispatcher)
            rescue StandardError => error
              org.neo4j.driver.internal.shaded.io.netty.handler.codec.DecoderException.new("Failed to read inbound message:\n#{org.neo4j.driver.internal.shaded.io.netty.buffer.ByteBufUtil.hex_dump(msg)}\n", error)
            ensure
              @input.stop
            end
          end
        end
      end
    end
  end
end
