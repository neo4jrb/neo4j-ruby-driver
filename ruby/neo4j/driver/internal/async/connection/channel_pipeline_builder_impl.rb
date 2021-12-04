module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class ChannelPipelineBuilderImpl

          def build(message_format, pipeline, logging)
            # inbound handlers
            pipeline.add_list(Inbound::ChunkDecoder.new(logging))
            pipeline.add_list(Inbound::MessageDecoder.new)
            pipeline.add_list(Inbound::InboundMessageHandler.new(message_format, logging))

            # outbound handlers
            pipeline.add_list(Outbound::OutboundMessageHandler::NAME, Outbound::OutboundMessageHandler.new(message_format, logging))

            # last one - error handler
            pipeline.add_list(Inbound::ChannelErrorHandler.new(logging))
          end
        end
      end
    end
  end
end
