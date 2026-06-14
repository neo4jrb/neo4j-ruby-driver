module TestkitBackend
  module Requests
    class GetRoutingTable < Request
      def process
        named_entity('RoutingTable',
                     **%i[routers writers readers]
                       .each_with_object(database: database, ttl: ttl_seconds) do |role, hash|
                       hash[role] = to_object.send(role).to_a.map { |address| address_string(address) }
                     end)
      end

      def to_object
        @obj ||= fetch(driver_id).routing_table(database)
      end

      private

      # testkit wants the routing table's ttl in whole seconds. Both flavors
      # expose the absolute expiry (epoch millis) — MRI from last_updated+ttl,
      # JRuby from Java's expirationTimestamp; recover the remaining seconds and
      # ceil so a sub-second-old table still reports its original whole-second
      # ttl rather than 999.
      def ttl_seconds
        [((to_object.expiration_timestamp - Time.now.to_f * 1000) / 1000.0).ceil, 0].max
      end

      # host:port (IPv6 bracketed), built from the host/port accessors both
      # address types expose. Not the address's own to_s: JRuby's Java
      # BoltServerAddress#toString renders host(connectionHost):port even when
      # the two are equal, which testkit's routing-table assertions reject.
      def address_string(address)
        host = address.host.to_s
        host.include?(':') && !host.start_with?('[') ? "[#{host}]:#{address.port}" : "#{host}:#{address.port}"
      end
    end
  end
end
