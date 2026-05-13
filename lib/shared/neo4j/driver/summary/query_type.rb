# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Mirrors org.neo4j.driver.summary.QueryType — coarse classification
      # of what a query did (read, write, both, or schema mutation).
      module QueryType
        READ_ONLY = 'r'
        WRITE_ONLY = 'w'
        READ_WRITE = 'rw'
        SCHEMA_WRITE = 's'
      end
    end
  end
end
