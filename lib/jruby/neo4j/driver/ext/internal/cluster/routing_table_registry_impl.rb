# frozen_string_literal: true

module Neo4j::Driver::Ext
  module Internal
    module Cluster
      module RoutingTableRegistryImpl
        def routing_table_handler(database)
          if database
            get_routing_table_handler(Neo4j::Driver::Internal::DatabaseName.database(database))
              .then { |it| it.get if it.present? }
          else
            # The default/home database is keyed under the server-resolved
            # name, not defaultDatabase(); in the single-table stub case
            # (testkit's get_routing_table() with no database) return it.
            handlers = Reflection.field(self, 'routingTableHandlers').values
            handlers.first if handlers.size == 1
          end
        end
      end
    end
  end
end
