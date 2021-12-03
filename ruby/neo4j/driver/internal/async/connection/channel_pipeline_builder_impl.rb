
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
