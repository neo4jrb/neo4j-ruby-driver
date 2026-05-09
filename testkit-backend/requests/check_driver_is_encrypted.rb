# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Whether the driver was constructed to enforce TLS. Derivable from
    # the URI scheme (`bolt+s` / `neo4j+s` / `bolt+ssc` / `neo4j+ssc`)
    # OR from an explicit `encrypted: true` option.
    #
    # DRIVER GAP: Driver doesn't expose its encryption state today. The
    # cleanest fix is `Driver#encrypted?` returning true when the URI
    # scheme is one of the +s/+ssc variants OR when @options[:encrypted]
    # was passed. ~5 lines of driver code; we stub for now to keep this
    # PR scoped to the testkit-backend protocol surface.
    class CheckDriverIsEncrypted < Data.define(:driver_id)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'CheckDriverIsEncrypted: Driver#encrypted? not yet exposed (see handler comment).'
        )
      end
    end
  end
end
