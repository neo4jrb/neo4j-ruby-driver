# frozen_string_literal: true

module Neo4j
  module Driver
    # Session-level control over idempotent auto-commit retries
    # (Feature:IdempotentRetries) — the MRI counterpart of the Java driver's
    # org.neo4j.driver.AutoCommitRetriesMode enum. Same constant names, MRI's
    # own (symbol) values, mirroring how AccessMode/RoutingControl are defined
    # here. Session#run acts on it (together with the driver-level
    # `auto_commit_retries_disabled` default) to retry an idempotent auto-commit
    # RUN once — see Session#auto_commit_retries_enabled?.
    module AutoCommitRetriesMode
      ENABLED = :enabled
      DISABLED = :disabled
      DEFAULT = :default
    end
  end
end
