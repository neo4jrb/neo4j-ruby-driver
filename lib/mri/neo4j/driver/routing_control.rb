# frozen_string_literal: true

module Neo4j
  module Driver
    # Per-query routing for `driver.execute_query` — the Java driver's
    # RoutingControl. It is the same READ/WRITE concept as AccessMode (Java's
    # execute_query lowers RoutingControl to AccessMode internally), so on MRI
    # we make it a synonym. Kept as a distinct name to mirror the Java API
    # surface (AccessMode for sessions, RoutingControl for queries) and to
    # allow the two to diverge later without an API change.
    RoutingControl = AccessMode
  end
end
