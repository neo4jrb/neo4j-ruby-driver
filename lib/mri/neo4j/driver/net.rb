# frozen_string_literal: true

module Neo4j
  module Driver
    # Mirrors Java's org.neo4j.driver.net package — just enough to let
    # cross-flavour callers (testkit-backend, user resolver code) build
    # ServerAddress values without branching on flavour.
    module Net
      ServerAddress = Data.define(:host, :port) do
        def self.of(host, port)
          new(host, port)
        end

        # "host:port" (IPv6 hosts bracketed) — matches Java's
        # ServerAddress.toString and Routing::ServerAddress#to_s. Without
        # this, the default Data inspect (`#<data … host="h", port=N>`)
        # leaks anywhere a caller stringifies the address: a custom
        # resolver returns Net::ServerAddress values and
        # Bolt::Connection#split_addr does `addr.to_s.rpartition(":")`,
        # which then split on the `::` inside the class name and fed the
        # tail to Integer() — the ArgumentError across the v4x4/v5x0
        # resolver routing tests.
        def to_s
          host.include?(':') && !host.start_with?('[') ? "[#{host}]:#{port}" : "#{host}:#{port}"
        end
      end
    end
  end
end
