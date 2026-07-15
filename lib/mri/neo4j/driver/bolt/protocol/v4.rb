# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 4.x handler for the pre-4.4 wire form. The driver
        # negotiates it for 4.2 and 4.3 (see ProtocolVersionHandler);
        # 4.4's wire additions (imp_user, the ROUTE map form) live in
        # the V44 subclass, which every 5.x handler descends from.
        class V4 < Base
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
