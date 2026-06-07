# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Cluster
          # The routed bolt connection source holds the RoutingTableRegistry
          # in a private `registry` field. Expose it under the name testkit's
          # GetRoutingTable chain expects (…connection_provider.routing_table_registry).
          module RoutedBoltConnectionSource
            def routing_table_registry
              Reflection.field(self, 'registry')
            end
          end
        end
      end
    end
  end
end
