# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Read the next record from a result, then extract a typed field.
    # `record_key` is the field index (or name); `type_name` is the
    # expected Cypher type ("CypherList", "CypherMap", etc.); `field`
    # is an optional path within nested structures (used to drill into
    # list/map elements).
    #
    # Used by typed-field tests where testkit wants to assert a specific
    # value at a specific path. We have all the pieces (Result#next,
    # Cypher.from_ruby) but lack the path-walking behaviour.
    #
    # DRIVER GAP: this is purely a backend feature, not a driver gap.
    # Implementation:
    #   1. result.next → record
    #   2. value = record[record_key]
    #   3. if `field` present, walk into value (list index / map key)
    #   4. assert value's Cypher type matches `type_name`
    #   5. wrap as Response::Field
    # Stubbed for now to keep this PR focused on protocol surface.
    class CypherTypeField < Data.define(:result_id, :record_key, :type, :field)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'CypherTypeField: typed-field extraction not implemented in backend (see handler comment).'
        )
      end
    end
  end
end
