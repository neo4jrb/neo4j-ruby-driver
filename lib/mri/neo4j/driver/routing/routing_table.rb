# frozen_string_literal: true

module Neo4j
  module Driver
    module Routing
      # Snapshot of the cluster's routing roles, plus mutators used by the
      # error→action handlers (`forget` on connection failure, `forget_writer`
      # on NotALeader / ForbiddenOnReadOnlyDatabase). Mirrors the design of
      # Java's ClusterRoutingTable + Python's _routing.RoutingTable.
      #
      # Threading: callers (LoadBalancer) hold @refresh_lock while mutating
      # or reading. Methods here are not internally synchronised.
      class RoutingTable
        # Servers don't always return a writer right away (e.g. cluster
        # mid-leader-election). The table is still usable for reads in
        # that window, but the next routing refresh should prefer the
        # initial address (the seed router) over the existing routers list
        # since the latter may have been populated by a leaderless reply.
        attr_reader :database, :routers, :readers, :writers,
                    :last_updated, :ttl, :initialized_without_writers

        ROLE_TO_KEY = { 'READ' => :readers, 'WRITE' => :writers, 'ROUTE' => :routers }.freeze

        # Build a table from the `rt` map returned by the BOLT ROUTE message:
        #   {ttl: 1000, db: "homedb", servers: [{addresses: [...], role: "READ"}, ...]}
        def self.from_response(rt, requested_database, clock: Internal::Clock.new)
          buckets = { readers: [], writers: [], routers: [] }
          (rt[:servers] || []).each do |server|
            key = ROLE_TO_KEY[server[:role]] or next
            (server[:addresses] || []).each { |addr| buckets[key] << ServerAddress.parse(addr) }
          end

          new(
            database: requested_database || rt[:db],
            routers: buckets[:routers].uniq,
            readers: buckets[:readers].uniq,
            writers: buckets[:writers].uniq,
            ttl: (rt[:ttl] || 0).to_f,
            clock: clock
          )
        end

        def initialize(database:, routers: [], readers: [], writers: [], ttl: 0, clock: Internal::Clock.new)
          @database = database
          @routers = routers.to_set
          @readers = readers.to_set
          @writers = writers.to_set
          @ttl = ttl
          @clock = clock
          @last_updated = @clock.realtime
          @initialized_without_writers = @writers.empty?
        end

        # A table is fresh when it isn't expired AND has the servers needed
        # for the requested access mode. An empty writers list is acceptable
        # for read-only acquires (initialized_without_writers state), but a
        # write-mode acquire needs a writer.
        def fresh?(readonly:, now: @clock.realtime)
          return false if expired?(now)
          return false if @routers.empty?

          readonly ? @readers.any? : @writers.any?
        end

        def expired?(now = @clock.realtime)
          now >= @last_updated + @ttl
        end

        # Absolute expiry in epoch millis (last_updated + ttl). testkit's
        # backend derives the relative ttl from this — uniformly with JRuby,
        # whose Java RoutingTable exposes only this absolute timestamp.
        def expiration_timestamp
          ((@last_updated + @ttl).to_f * 1000).round
        end

        # Past the cache grace period? Used by LoadBalancer to drop tables
        # for databases nobody is touching anymore.
        def purge?(grace:, now: @clock.realtime)
          now >= @last_updated + @ttl + grace
        end

        # Replace the contents in place with another table's roles. The
        # existing table identity is preserved so anyone holding a reference
        # sees the new state.
        def update(other)
          @routers = other.routers.dup
          @readers = other.readers.dup
          @writers = other.writers.dup
          @ttl = other.ttl
          @last_updated = @clock.realtime
          @initialized_without_writers = @writers.empty?
        end

        # Remove an address from every role bucket. Called on connection
        # failure: the server is gone, drop it everywhere.
        def forget(address)
          @routers.delete(address)
          @readers.delete(address)
          @writers.delete(address)
        end

        # Remove an address only from the writers bucket. Called when a
        # WRITE op fails with NotALeader / ForbiddenOnReadOnlyDatabase:
        # the server is alive but no longer the leader, so it can still
        # serve reads.
        def forget_writer(address)
          @writers.delete(address)
        end

        def servers_for(access_mode)
          case access_mode
          when :read  then @readers
          when :write then @writers
          when :route then @routers
          else raise ArgumentError, "Unknown access mode: #{access_mode.inspect}"
          end
        end

        # Union of all role buckets — used when shutting down per-server
        # pools that no current routing table references.
        def servers
          @routers | @readers | @writers
        end
      end
    end
  end
end
