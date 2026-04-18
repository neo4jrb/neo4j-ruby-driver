# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 4.x protocol handler
        class V4 < Base
          def build_hello_message(user_agent:, auth:, routing: nil)
            extra = { user_agent: user_agent }
            extra[:routing] = routing if routing
            # Bolt 4.x also merges auth into extra map (1 field)
            extra.merge!(auth) if auth
            PackStream::Structure.new(Message::HELLO, [extra])
          end

          def supports_multiple_databases?
            true
          end
        end
      end
    end
  end
end
