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

          # ROUTE's third field changed at 4.4. 4.3 sends the target
          # database as a bare string (or null for the home db); 4.4+
          # send a `{db, imp_user}` map (imp_user being 4.4's addition).
          # Inherited unchanged by every 5.x handler (all subclasses of
          # V4), which keep the map form.
          def build_route(routing_context, bookmarks, database, imp_user)
            third =
              if version >= BoltVersion::V4_4
                { db: database, imp_user: imp_user }.compact
              else
                database
              end
            Message.route(routing_context, bookmarks, third)
          end
        end
      end
    end
  end
end
