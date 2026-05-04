# frozen_string_literal: true

module Neo4j
  module Driver
    module Routing
      # Snapshot of the cluster's routing roles at the time of a ROUTE call.
      # `expires_at` is the absolute deadline; #expired? answers refresh-needed.
      class RoutingTable < Data.define(:database, :readers, :writers, :routers, :expires_at)
        ROLE_TO_KEY = { 'READ' => :readers, 'WRITE' => :writers, 'ROUTE' => :routers }.freeze

        # Build from the `rt` map returned by the ROUTE message:
        #   {ttl: 1000, db: "homedb", servers: [{addresses: [...], role: "READ"}, ...]}
        def self.from_response(rt, requested_database)
          buckets = { readers: [], writers: [], routers: [] }
          (rt[:servers] || []).each do |server|
            key = ROLE_TO_KEY[server[:role]] or next
            (server[:addresses] || []).each { |addr| buckets[key] << ServerAddress.parse(addr) }
          end

          new(
            database: requested_database || rt[:db],
            readers: buckets[:readers].uniq,
            writers: buckets[:writers].uniq,
            routers: buckets[:routers].uniq,
            expires_at: Time.now + (rt[:ttl] || 0)
          )
        end

        def expired?(now = Time.now)
          now >= expires_at
        end

        def servers_for(role)
          case role
          when :read  then readers
          when :write then writers
          when :route then routers
          else raise ArgumentError, "Unknown role: #{role.inspect}"
          end
        end
      end
    end
  end
end
