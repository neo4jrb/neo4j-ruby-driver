# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 4.x protocol handler
        class V4 < Base
          def build_hello_message(user_agent:, auth:, routing: nil)
            PackStream::Structure.new(Message::HELLO, [{ user_agent:, routing:, **auth }.compact])
          end

          def supports_multiple_databases? = true
        end
      end
    end
  end
end
