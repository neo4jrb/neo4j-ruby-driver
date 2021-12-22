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

          def to_s
            metadata_copy = metadata.merge(Security::InternalAuthToken::CREDENTIALS_KEY => '******')
            "HELLO #{metadata_copy}"
          end

          private

          def self.build_metadata(user_agent, auth_token, routing_context)
            auth_token.merge(
              USER_AGENT_METADATA_KEY => user_agent,
              ROUTING_CONTEXT_METADATA_KEY => routing_context
            ).compact
          end
        end
      end
    end
  end
end
