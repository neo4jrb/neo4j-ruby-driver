# frozen_string_literal: true

module Neo4j
  module Driver
    module Routing
      # Host:port pair for a single Bolt server. Hashable so it works as
      # a key in the LoadBalancer's per-server pool map.
      class ServerAddress < Data.define(:host, :port)
        DEFAULT_PORT = 7687

        # Parse "host:port" or "[ipv6]:port" (or bare "host" → default port).
        def self.parse(string)
          host, sep, port = string.to_s.rpartition(':')
          return new(host: string.to_s, port: DEFAULT_PORT) if sep.empty?

          new(host: host, port: Integer(port))
        end

        def to_s
          host.include?(':') && !host.start_with?('[') ? "[#{host}]:#{port}" : "#{host}:#{port}"
        end
      end
    end
  end
end
