module Testkit::Backend::Messages
  module Requests
    class GetRoutingTable < Request
      def process
        named_entity('RoutingTable',
                     **%i[routers writers readers]
                       .each_with_object(database: database, ttl: nil) do |method, hash|
                       hash[method] = to_object.send(method).to_a.map(&:to_s)
                     end)
      end

      def to_object
        @obj ||= fetch(driver_id).session_factory.connection_provider.routing_table_registry
                                .routing_table_handler(database).routing_table
      end
    end
  end
end
