# frozen_string_literal: true

module Neo4j::Driver::Ext
  module Internal
    module Cluster
      module RoutingTableRegistryImpl
        def routing_table_handler(database)
          if database
            it = get_routing_table_handler(Neo4j::Driver::Internal::DatabaseName.database(database))
            raise KeyError, "No routing table for database #{database.inspect}" unless it.present?

            it.get
          else
            # The default/home database is keyed under the server-resolved
            # name, not defaultDatabase(); in the single-table stub case
            # (testkit's get_routing_table() with no database) return it.
            handlers = Reflection.field(self, 'routingTableHandlers').values
            unless handlers.size == 1
              raise KeyError, "Cannot resolve default routing table (#{handlers.size} present; specify a database)"
            end

            handlers.first
          end
        end
      end
    end
  end
end
