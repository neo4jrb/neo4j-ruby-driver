module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingSettings
        attr_reader :max_routing_failures, :retry_timeout_delay, :routing_context, :routing_table_purge_delay

        def initialize(max_routing_failures, retry_timeout_delay, routing_table_purge_delay,
                       routing_context = RoutingContext::EMPTY)
          @max_routing_failures = max_routing_failures
          @retry_timeout_delay = retry_timeout_delay
          @routing_context = routing_context
          @routing_table_purge_delay = routing_table_purge_delay
        end

        STALE_ROUTING_TABLE_PURGE_DELAY = 30.seconds
        DEFAULT = new(1, 5.seconds, STALE_ROUTING_TABLE_PURGE_DELAY)

        def with_routing_context(new_routing_context)
          self.class.new(@max_routing_failures, @retry_timeout_delay, @routing_table_purge_delay, new_routing_context)
        end
      end
    end
  end
end
