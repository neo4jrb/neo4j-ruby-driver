module Testkit::Backend::Messages
  module Requests
    class GetConnectionPoolMetrics < Request
      def process
        uri = URI(address)
        pool_metrics = fetch(driver_id).metrics.connection_pool_metrics.find do |pm|
                         pm.address.host == uri.host && pm.address.port ==  uri.port
                       end

        reference('ConnectionPoolMetrics', inUse: pool_metrics.in_use, idle: pool_metrics.idle)
      end
    end
  end
end
