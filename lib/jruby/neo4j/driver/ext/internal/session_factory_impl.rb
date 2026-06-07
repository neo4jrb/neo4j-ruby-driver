# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # The 6.x Java driver no longer exposes a ConnectionProvider off the
        # session factory — the routing-table registry now lives in the
        # shaded bolt-connection-routed layer, reachable only via private
        # fields: SessionFactoryImpl#connectionSource (an
        # AdaptingDriverBoltConnectionSource) wraps a `delegate` which, for a
        # routing (neo4j://) driver, is the RoutedBoltConnectionSource that
        # holds the registry. Reflect through to it so testkit's
        # impl-agnostic GetRoutingTable chain
        # (session_factory.connection_provider.routing_table_registry…)
        # keeps working on JRuby the same as on MRI.
        module SessionFactoryImpl
          def connection_provider
            Reflection.field(Reflection.field(self, 'connectionSource'), 'delegate')
          end
        end
      end
    end
  end
end
