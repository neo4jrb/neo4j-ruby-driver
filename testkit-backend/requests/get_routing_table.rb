# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Returns the current routing table snapshot for the given database
    # (or default DB if nil). Test-only API.
    #
    # Real impl in Driver#routing_table_snapshot → LoadBalancer#snapshot,
    # which may trigger a fetch if the cache is empty/expired. Raises
    # ClientException on a direct (`bolt://`) driver.
    class GetRoutingTable < Data.define(:driver_id, :database)
      include Request

      def execute
        table = registry.fetch(driver_id).routing_table_snapshot(database)
        Response::RoutingTable.new(
          database: table.database,
          ttl: ((table.expires_at - Time.now) * 1000).to_i,  # ms remaining
          routers: table.routers.map(&:to_s),
          readers: table.readers.map(&:to_s),
          writers: table.writers.map(&:to_s)
        )
      end
    end
  end
end
