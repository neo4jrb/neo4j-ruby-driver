
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
        class ChannelAttributes

          CONNECTION_ID = io.netty.util.AttributeKey.new_instance('connectionId')
          POOL_ID = io.netty.util.AttributeKey.new_instance('poolId')
          PROTOCOL_VERSION = io.netty.util.AttributeKey.new_instance('protocolVersion')
          SERVER_AGENT = io.netty.util.AttributeKey.new_instance('serverAgent')
          ADDRESS = io.netty.util.AttributeKey.new_instance('serverAddress')
          SERVER_VERSION = io.netty.util.AttributeKey.new_instance('serverVersion')
          CREATION_TIMESTAMP = io.netty.util.AttributeKey.new_instance('creationTimestamp')
          LAST_USED_TIMESTAMP = io.netty.util.AttributeKey.new_instance('lastUsedTimestamp')
          MESSAGE_DISPATCHER = io.netty.util.AttributeKey.new_instance('messageDispatcher')
          TERMINATION_REASON = io.netty.util.AttributeKey.new_instance('terminationReason')
          AUTHORIZATION_STATE_LISTENER = io.netty.util.AttributeKey.new_instance('authorizationStateListener')
          CONNECTION_READ_TIMEOUT = io.netty.util.AttributeKey.new_instance('connectionReadTimeout')
          
          class << self
            def connection_id(channel)
              get(channel, CONNECTION_ID)
            end

            def set_connection_id(channel, id)
              set_once(channel, CONNECTION_ID, id)
            end

            def pool_id(channel)
              get(channel, POOL_ID)
            end

            def set_pool_id(channel, id)
              set_once(channel, POOL_ID, id)
            end

            def protocol_version(channel)
              get(channel, PROTOCOL_VERSION)
            end

            def set_protocol_version(channel, version)
              set_once(channel, PROTOCOL_VERSION, version)
            end

            def set_server_agent(channel, server_agent)
              set_once(channel, SERVER_AGENT, server_agent)
            end

            def server_agent(channel)
              get(channel, SERVER_AGENT)
            end

            def server_address(channel)
              get(channel, ADDRESS)
            end

            def set_server_address(channel, address)
              set_once(channel, ADDRESS, address)
            end

            def server_version(channel)
              get(channel, SERVER_VERSION)
            end

            def set_server_version(channel, version)
              set_once(channel, SERVER_VERSION, version)
            end

            def creation_timestamp(channel)
              get(channel, CREATION_TIMESTAMP)
            end

            def set_creation_timestamp(channel, creation_timestamp)
              set_once(channel, CREATION_TIMESTAMP, creation_timestamp)
            end

            def last_used_timestamp(channel)
              get(channel, LAST_USED_TIMESTAMP)
            end

            def set_last_used_timestamp(channel, last_used_timestamp)
              set(channel, LAST_USED_TIMESTAMP, last_used_timestamp)
            end

            def message_dispatcher(channel)
              get(channel, MESSAGE_DISPATCHER)
            end

            def set_message_dispatcher(channel, message_dispatcher)
              set_once(channel, MESSAGE_DISPATCHER, message_dispatcher)
            end

            def termination_reason(channel)
              get(channel, TERMINATION_REASON)
            end

            def set_termination_reason(channel, termination_reason)
              set_once(channel, TERMINATION_REASON, termination_reason)
            end

            def authorization_state_listener(channel)
              get(channel, AUTHORIZATION_STATE_LISTENER)
            end

            def set_authorization_state_listener(channel, authorization_state_listener)
              set(channel, AUTHORIZATION_STATE_LISTENER, authorization_state_listener)
            end

            def connection_read_timeout(channel)
              get(channel, CONNECTION_READ_TIMEOUT)
            end

            def set_connection_read_timeout(channel, connection_read_timeout)
              set_once(channel, CONNECTION_READ_TIMEOUT, connection_read_timeout)
            end

            def get(channel, key)
              channel.attr(key).get
            end

            def set(channel, key, value)
              channel.attr(key).set(value)
            end

            def set_once(channel, key, value)
              existing_value = channel.attr(key).set_if_absent(value)

              unless existing_value.nil?
                raise Neo4j::Driver::Exceptions::CertificateException::IllegalStateException, "Unable to set #{key.name} because it is already set to #{existing_value}"
              end
            end
          end
        end
      end
    end
  end
end
