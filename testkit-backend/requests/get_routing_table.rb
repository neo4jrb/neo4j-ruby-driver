module TestkitBackend
  module Requests
    class GetRoutingTable < Request
      def process
        # MRI's RoutingTable exposes `.ttl` (relative seconds from the
        # ROUTE response). JRuby wraps Java's RoutingTable which only
        # exposes `.expirationTimestamp()` (absolute millis); leave the
        # ttl as 0 there until/unless a JRuby-side translation is added.
        named_entity('RoutingTable',
                     **%i[routers writers readers]
                       .each_with_object(database: database, ttl: to_object.try(:ttl).to_i) do |method, hash|
                       hash[method] = to_object.send(method).to_a.map(&:to_s)
                     end)
      end

      def to_object
        @obj ||= fetch(driver_id).routing_table(database)
      end
    end
  end
end
