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
      end
    end
  end
end
