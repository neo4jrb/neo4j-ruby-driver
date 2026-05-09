# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Forces the driver to refresh its routing table for the given
    # database NOW, ignoring TTL/cache. Test-only API — never exposed
    # to driver users. Testkit uses it to set up scenarios for failure-
    # injection tests.
    #
    # DRIVER GAP: we have routing (Routing::LoadBalancer / RoutingTable)
    # but no public method to force a refresh from outside. Java's
    # reference: org.neo4j.driver.internal.InternalDriver expose a
    # `routingTableRegistry().refresh(...)` test-internal entry point.
    # The cleanest port:
    #   - Routing::LoadBalancer#force_refresh(database, bookmarks)
    #   - Driver delegates to it when scheme is routing; raises ArgumentError
    #     otherwise (forced-refresh on a direct driver is meaningless)
    class ForcedRoutingTableUpdate < Data.define(:driver_id, :database, :bookmarks)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'ForcedRoutingTableUpdate: routing table not exposed for forced refresh (see handler comment).'
        )
      end
    end
  end
end
