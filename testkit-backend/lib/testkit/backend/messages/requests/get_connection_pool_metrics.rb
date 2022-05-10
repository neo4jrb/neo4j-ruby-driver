module Testkit::Backend::Messages
  module Requests
    class GetConnectionPoolMetrics < Request
      def process
        uri = Neo4j::Driver::Internal::BoltServerAddress.uri_from(address)
        pool_metrics = fetch(driverId).metrics.connection_pool_metrics.find do |pm|
                         pm.address.host == uri.host && pm.address.port ==  uri.port
                       end
        named_entity('ConnectionPoolMetrics', inUse: pool_metrics.in_use, idle: pool_metrics.idle)
      end
    end
  end
end
