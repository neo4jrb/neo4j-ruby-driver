module Testkit::Backend::Messages
  module Requests
    class GetConnectionPoolMetrics < Request
      def process
        uri = Neo4j::Driver::Internal::BoltServerAddress.uri_from(address)
        pool_metrics = fetch(driver_id).metrics.connection_pool_metrics.find do |pm|
          pm_address = pm.address
          pm_address.host == uri.host && pm_address.port == uri.port
        end
        raise ArgumentError, "Pool metrics for #{address} are not available" unless pool_metrics
        named_entity('ConnectionPoolMetrics', inUse: pool_metrics.in_use, idle: pool_metrics.idle)
      end
    end
  end
end
