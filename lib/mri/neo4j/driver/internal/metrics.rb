# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Driver metrics surface (testkit's `driver.metrics`). Today only the
      # per-server connection-pool metrics are exposed — how many connections
      # to each server address are in use vs. idle — which is what testkit's
      # GetConnectionPoolMetrics / test_should_drop_connections_failing_
      # liveness_check reads. The provider (Direct or Routing::LoadBalancer)
      # owns the pools, so it produces the per-address snapshots.
      class Metrics
        # Per-server-address snapshot. `address` is a Routing::ServerAddress
        # (responds to #host/#port so the testkit handler can match it).
        ConnectionPoolMetrics = Struct.new(:address, :in_use, :idle)

        def initialize(connection_provider)
          @connection_provider = connection_provider
        end

        def connection_pool_metrics
          @connection_provider.connection_pool_metrics
        end
      end
    end
  end
end
