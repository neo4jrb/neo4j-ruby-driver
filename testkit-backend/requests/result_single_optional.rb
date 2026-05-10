# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Real impl: Result#single_optional returns [record_or_nil,
    # warnings_array]. Drains the stream in all cases.
    class ResultSingleOptional < Data.define(:result_id)
      include Request

      def execute
        record, warnings = registry.fetch(result_id).single_optional
        Response::RecordOptional.new(
          record: record && Response::Record.from_driver_record(record),
          warnings: warnings
        )
      end
    end
  end
end
