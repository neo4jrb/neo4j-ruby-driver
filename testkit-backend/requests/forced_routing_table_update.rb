# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Forces a fresh fetch of the routing table for the given database,
    # ignoring TTL/cache. Test-only API; raises ClientException on a
    # direct (`bolt://`) driver where routing-table semantics don't apply.
    #
    # Real impl in Driver#force_routing_table_update → LoadBalancer#force_refresh.
    class ForcedRoutingTableUpdate < Data.define(:driver_id, :database, :bookmarks)
      include Request

      def execute
        registry.fetch(driver_id).force_routing_table_update(database, bookmarks)
        Response::Driver.new(id: driver_id)
      end
    end
  end
end
