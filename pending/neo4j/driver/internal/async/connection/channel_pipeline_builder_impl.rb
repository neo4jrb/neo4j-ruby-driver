module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class ChannelPipelineBuilderImpl
          def build(message_format, pipeline, logger)
            # inbound handlers
            pipeline.add_last(Inbound::ChunkDecoder.new(logger))
            pipeline.add_last(Inbound::MessageDecoder.new)
            pipeline.add_last(Inbound::InboundMessageHandler.new(message_format, logger))

            # outbound handlers
            pipeline.add_last(Outbound::OutboundMessageHandler::NAME, Outbound::OutboundMessageHandler.new(message_format, logger))

            # last one - error handler
            pipeline.add_last(Inbound::ChannelErrorHandler.new(logger))
          end
        end
      end
    end
  end
end
