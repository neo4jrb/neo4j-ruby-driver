# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Mirrors org.neo4j.driver.summary.QueryType — coarse classification
      # of what a query did (read, write, both, or schema mutation).
      module QueryType
        READ_ONLY = :read_only
        WRITE_ONLY = :write_only
        READ_WRITE = :read_write
        SCHEMA_WRITE = :schema_write
      end
    end
  end
end
