# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Per-server-address pool occupancy. Mirrors the slice of Java's
      # ConnectionPoolMetrics testkit reads: the `address` it was opened for
      # and the in-use / idle connection counts. Test-only — surfaced via
      # Driver#metrics for testkit's GetConnectionPoolMetrics.
      ConnectionPoolMetrics = Struct.new(:address, :in_use, :idle)
    end
  end
end
