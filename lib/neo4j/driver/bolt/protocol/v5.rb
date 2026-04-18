# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.x protocol handler
        class V5 < Base
          def build_hello_message(user_agent:, auth:, routing: nil)
            extra = { user_agent: user_agent }
            extra[:routing] = routing if routing
            # Bolt 5.x merges auth into extra map (1 field in structure)
            extra.merge!(auth) if auth
            PackStream::Structure.new(Message::HELLO, [extra])
          end

          def supports_multiple_databases?
            true
          end

          def supports_notification_filtering?
            version >= BoltVersion::V5_7
          end

          def supports_re_auth?
            version >= BoltVersion::V5_1
          end
        end
      end
    end
  end
end
