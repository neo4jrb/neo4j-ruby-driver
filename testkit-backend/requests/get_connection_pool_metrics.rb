# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Returns connection pool metrics (in_use, idle counts) for a
    # specific server address. Test-only API.
    #
    # DRIVER GAP: connection pool metrics infrastructure doesn't exist
    # yet. We use the connection_pool gem which has #size and #available
    # but those are for the global pool — testkit asks per-address
    # (a routing driver maintains a pool per server). Required pieces:
    #   - Track ConnectionPool instances keyed by ServerAddress
    #     (Routing::LoadBalancer probably already does this; expose it)
    #   - Per-pool counters: total acquired - currently_returned = in_use;
    #     currently_pooled = idle
    #   - Driver#pool_metrics(address) returning {in_use:, idle:}
    class GetConnectionPoolMetrics < Data.define(:driver_id, :address)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'GetConnectionPoolMetrics: pool metrics infrastructure not implemented (see handler comment).'
        )
      end
    end
  end
end
