module TestkitBackend
  module Requests
    class GetConnectionPoolMetrics < Request
      def process
        uri = URI.parse(address.start_with?('bolt') ? address : "bolt://#{address}")
        pool_metrics = fetch(driver_id).metrics.connection_pool_metrics.find do |pm|
          pm.address.host == uri.host && pm.address.port == uri.port
        end
        raise ArgumentError, "Pool metrics for #{address} are not available" unless pool_metrics

        named_entity('ConnectionPoolMetrics', inUse: pool_metrics.in_use, idle: pool_metrics.idle)
      end
    end
  end
end
