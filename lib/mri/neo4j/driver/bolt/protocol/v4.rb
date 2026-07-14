# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 4.0–4.3 protocol handler. HELLO is unchanged across the
        # 4.x minors, so this class covers 4.2/4.3; 4.4's wire additions
        # (imp_user, the ROUTE map form) live in the V44 subclass, which
        # every 5.x handler descends from.
        class V4 < Base
          def hello_extra(user_agent:, auth:, routing:)
            { user_agent:, routing:, **auth }
          end

          def supports_multiple_databases? = true

          # ROUTE's third field is the target database as a bare string
          # (or null for the home db). 4.4 changed it to a `{db, imp_user}`
          # map — V44 overrides this; imp_user is unused here.
          def build_route(routing_context, bookmarks, database, _imp_user)
            Message.route(routing_context, bookmarks, database)
          end
        end
      end
    end
  end
end
