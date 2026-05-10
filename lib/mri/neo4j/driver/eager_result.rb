# frozen_string_literal: true

module Neo4j
  module Driver
    # Materialised query result returned by Driver#execute_query: keys
    # (column names), records (already-drained array), and the consumed
    # summary. Modelled on Java's org.neo4j.driver.EagerResult.
    EagerResult = Struct.new(:keys, :records, :summary)
  end
end
