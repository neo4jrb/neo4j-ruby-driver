module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class ChannelAttributes < Hash
          # CONNECTION_ID = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('connectionId')
          # POOL_ID = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('poolId')
          # PROTOCOL_VERSION = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('protocolVersion')
          # SERVER_AGENT = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('serverAgent')
          # ADDRESS = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('serverAddress')
          # SERVER_VERSION = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('serverVersion')
          # CREATION_TIMESTAMP = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('creationTimestamp')
          # LAST_USED_TIMESTAMP = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('lastUsedTimestamp')
          # MESSAGE_DISPATCHER = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('messageDispatcher')
          # TERMINATION_REASON = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('terminationReason')
          # AUTHORIZATION_STATE_LISTENER = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('authorizationStateListener')
          # CONNECTION_READ_TIMEOUT = org.neo4j.driver.internal.shaded.io.netty.util.AttributeKey.new_instance('connectionReadTimeout')

          UPDATABLE_KEYS = %i[last_used_timestamp authorization_state_listener]

          def []=(key, value)
            if !UPDATABLE_KEYS.include?(key) && key?(key)
              raise Neo4j::Driver::Exceptions::IllegalStateException, "Unable to set #{key} because it is already set to #{self[key]}"
            end
            super
          end
        end
      end
    end
  end
end
