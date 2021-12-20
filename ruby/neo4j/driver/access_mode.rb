# frozen_string_literal: true

# Used by Routing Driver to decide if a transaction should be routed to a write server or a read server in a cluster.
# When running a transaction, a write transaction requires a server that supports writes.
# A read transaction, on the other hand, requires a server that supports read operations.
# This classification is key for routing driver to route transactions to a cluster correctly.
#
# While any {@link AccessMode} will be ignored while running transactions via a driver towards a single server.
# As the single server serves both read and write operations at the same time.
module Neo4j::Driver::AccessMode
  # Use this for transactions that requires a read server in a cluster
  READ = Java::OrgNeo4jDriver::AccessMode::READ # TO DO: replace this with :read once all java refs are done

  # Use this for transactions that requires a write server in a cluster
  WRITE = Java::OrgNeo4jDriver::AccessMode::WRITE # :write # TO DO: replace this with :write once all java refs are done
end
