 # frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 4.4. Adds impersonation (imp_user on RUN/BEGIN/ROUTE) and
        # changes ROUTE's third field from a bare database string to a
        # `{db, imp_user}` map. Descends from V43 so it inherits the "utc"
        # patch capability; every 5.x handler descends from this class, so
        # they inherit impersonation, the ROUTE map form, and (until V5
        # turns it off) the patch.
        class V44 < V43
          def supports_impersonation? = true

          def build_route(routing_context, bookmarks, database, imp_user)
            Message.route(routing_context, bookmarks, { db: database, imp_user: }.compact)
          end
        end
      end
    end
  end
end
