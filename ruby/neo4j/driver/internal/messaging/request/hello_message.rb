module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class HelloMessage < MessageWithMetadata
          SIGNATURE = 0x01
          USER_AGENT_METADATA_KEY = 'user_agent'
          ROUTING_CONTEXT_METADATA_KEY = 'routing'

          def initialize(user_agent, auth_token, routing_context)
            super(build_metadata(user_agent, auth_token, routing_context))
          end

          def equals(object)
            return true if self == object

            return false if object.nil? || self.class != object.class

            java.util.Objects.equals(metadata, object.metadata)
          end

          def hash_code
            java.util.Objects.hash(metadata)
          end

          def to_s
            metadata_copy = metadata
            metadata_copy[Security::InternalAuthToken::CREDENTIALS_KEY] = Values.value('******')
            "HELLO #{metadata_copy}"
          end

          private

          def self.buildMetadata(user_agent, auth_token, routing_context)
            result = auth_token
            result[USER_AGENT_METADATA_KEY] = Values.value(user_agent)
            result[ROUTING_CONTEXT_METADATA_KEY] = Values.value(routing_context) unless routing_context.nil?
            result
          end
        end
      end
    end
  end
end
