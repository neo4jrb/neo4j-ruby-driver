# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Thin Driver#metrics facade. The only consumer is testkit's
      # GetConnectionPoolMetrics, which walks `connection_pool_metrics`;
      # the actual per-address counts come from the ConnectionProvider, which
      # owns the pools.
      class Metrics
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
