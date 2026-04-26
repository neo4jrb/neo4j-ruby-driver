# frozen_string_literal: true

module TestkitBackend
  module Requests
    class ResultPeek < Data.define(:result_id)
      include Request

      def execute
        result = registry.fetch(result_id)
        return Response::NullRecord.new unless result.has_next?

        Response::Record.from_driver_record(result.peek)
      end
    end
  end
end
