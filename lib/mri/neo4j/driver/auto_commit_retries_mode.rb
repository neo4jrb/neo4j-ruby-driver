# frozen_string_literal: true

module Neo4j
  module Driver
    # Session-level control over idempotent auto-commit retries
    # (Feature:IdempotentRetries) — the MRI counterpart of the Java driver's
    # org.neo4j.driver.AutoCommitRetriesMode enum. Same constant names, MRI's
    # own (symbol) values, mirroring how AccessMode/RoutingControl are defined
    # here. Defined so the shared testkit-backend can name the mode
    # flavor-agnostically; the pure-Ruby Bolt 6.0 retry path is not yet
    # implemented, so MRI does not act on it.
    module AutoCommitRetriesMode
      ENABLED = :enabled
      DISABLED = :disabled
      DEFAULT = :default
    end
  end
end
