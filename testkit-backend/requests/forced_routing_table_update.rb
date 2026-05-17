module TestkitBackend
  module Requests
    # Mirrors the chain used by GetRoutingTable so the handler works
    # on both impls. JRuby's RoutingTableRegistry doesn't yet expose
    # `refresh` (Java's force-refresh path needs ClusterComposition
    # parameters that aren't trivial to build from Ruby), so the call
    # is gated on respond_to?. testkit only sends this request when
    # the impl advertises `Feature.BACKEND_RT_FORCE_UPDATE` (see
    # GetFeatures), so the no-op path is unreachable in practice.
    class ForcedRoutingTableUpdate < Request
      def process
        registry = fetch(driver_id).session_factory.connection_provider.routing_table_registry
        registry.refresh(database, bookmarks) if registry.respond_to?(:refresh)
        named_entity('Driver', id: driver_id)
      end
    end
  end
end
