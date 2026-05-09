# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Returns a RecordOptional: at-most-one record, exhausting the stream.
    # Differs from ResultSingle (which raises on zero or >1) — single_optional
    # tolerates zero (returns nil record) and reports >1 as a warning.
    #
    # DRIVER GAP: Neo4j::Driver::Result has #single (zero/2+ both raise) but
    # no `#single_optional`. Implementing it is small (~10 lines: read
    # has_next?, read one if any, drain rest, build warning if there were
    # more). For now we wrap #single with rescue-on-empty as a partial
    # impl; the >1 case still raises rather than warning. Promote when
    # Result#single_optional lands.
    class ResultSingleOptional < Data.define(:result_id)
      include Request

      def execute
        result = registry.fetch(result_id)
        record = result.single
        Response::RecordOptional.new(
          record: Response::Record.from_driver_record(record),
          warnings: []
        )
      rescue Neo4j::Driver::Exceptions::NoSuchRecordException => e
        # Empty result: testkit expects record=nil, warnings=[].
        # The "result has more than one record" path also raises this in
        # our Result#single — that's a partial behaviour mismatch; once
        # Result#single_optional lands we can distinguish.
        if e.message.include?('empty')
          Response::RecordOptional.new(record: nil, warnings: [])
        else
          Response::DriverError.from(e, registry: registry)
        end
      end
    end
  end
end
