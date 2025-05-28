# frozen_string_literal: true

module Neo4j
  module Driver
    module NotificationClassification
      DEPRECATION = :deprecation
      GENERIC = :generic
      HINT = :hint
      PERFORMANCE = :performance
      SCHEMA = :schema
      SECURITY = :security
      TOPOLOGY = :topology
      UNRECOGNIZED = :unrecognized
      UNSUPPORTED = :unsupported
    end
  end
end
