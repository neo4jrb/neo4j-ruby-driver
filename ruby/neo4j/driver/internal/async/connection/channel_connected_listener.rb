
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
        class ChannelConnectedListener < Struct.new(:address, :pipeline_builder, :handshake_completed_promise
                                                    :logging)
          def operation_complete(future)
            channel = future.channel
            log = Logging::ChannelActivityLogger.new(channel, logging, get_class)

            if future.is_success?
              log.trace("Channel #{channel} connected, initiating bolt handshake")

              pipeline = channel.pipeline
              pipeline.add_list(HandshakeHandler.new(pipeline_builder, handshake_completed_promise, logging))
              log.debug("C: [Bolt Handshake] #{BoltProtocolUtil.handshake_string}")
              channel.write_and_flush(BoltProtocolUtil.handshake_buf, channel.void_promise)
            else
              handshake_completed_promise.set_failure(database_unavailable_error(address, future.cause))
            end
          end

          def self.database_unavailable_error(address, cause)
            Neo4j::Driver::Exceptions::ServiceUnavailableException, java.lang.String.format(
              "Unable to connect to #{address}, ensure the database is running and that there is a working network connection to it.",
              cause)
          end
        end
      end
    end
  end
end