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
            # The routed provider holding the registry sits behind one or
            # more delegating wrappers whose count varies by driver version
            # (6.0.x: AdaptingDriverBoltConnectionSource → routed;
            # 6.1.x adds a ProviderClosingBoltConnectionSource in between).
            # Unwrap `delegate` until the source that owns the registry.
            source = Reflection.field(self, 'connectionSource')
            until Reflection.field?(source, 'registry')
              unless Reflection.field?(source, 'delegate')
                raise KeyError, "No routing-table registry in the connection-source chain (#{source.java_class.simple_name})"
              end

              source = Reflection.field(source, 'delegate')
            end
            source
          end
        end
      end
    end
  end
end
