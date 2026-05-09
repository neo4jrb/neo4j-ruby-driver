# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Returns the current routing table (database, ttl, routers, readers,
    # writers as address strings). Test-only — not part of the public
    # driver API. Testkit asserts the routing-protocol behaviour.
    #
    # DRIVER GAP: Routing::RoutingTable carries the data already; the
    # missing piece is a Driver-level accessor that takes a database
    # name and returns the snapshot. Cleanest port:
    #   - Routing::LoadBalancer#snapshot(database) -> a small struct
    #   - Driver delegates when routing; raises on direct driver
    # Conversion from internal RoutingTable to Response::RoutingTable's
    # field shape is straightforward (addresses already as strings).
    class GetRoutingTable < Data.define(:driver_id, :database)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'GetRoutingTable: routing table snapshot not exposed (see handler comment).'
        )
      end
    end
  end
end
