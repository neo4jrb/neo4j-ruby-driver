# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 4.x protocol handler. Single class for the 4.x family
        # because each minor's additions are wire-additive (4.3 added
        # ROUTE; 4.4 added imp_user / hints) and don't change HELLO.
        # Per-minor version checks (e.g. ROUTE only on 4.3+) live where
        # the senders do, not here.
        class V4 < Base
          def hello_extra(user_agent:, auth:, routing:)
            { user_agent:, routing:, **auth }
          end

          def supports_multiple_databases? = true
        end
      end
    end
  end
end
