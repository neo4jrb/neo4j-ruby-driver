module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingSettings
        attr_reader :max_routing_failures, :retry_timeout_delay, :routing_context, :routing_table_purge_delay_ms

        def initialize(max_routing_failures, retry_timeout_delay, routing_table_purge_delay_ms, routing_context = RoutingContext::EMPTY)
          @max_routing_failures = max_routing_failures
          @retry_timeout_delay = retry_timeout_delay
          @routing_context = routing_context
          @routing_table_purge_delay_ms = routing_table_purge_delay_ms
        end

        STALE_ROUTING_TABLE_PURGE_DELAY_MS = java.util.concurrent.TimeUnit::SECONDS.to_millis(30)
        DEFAULT = new(1, java.util.concurrent.TimeUnit::SECONDS.to_millis(5), STALE_ROUTING_TABLE_PURGE_DELAY_MS)

        def with_routing_context(new_routing_context)
          new(max_routing_failures, retry_timeout_delay, routing_table_purge_delay_ms, new_routing_context)
        end
      end
    end
  end
end
