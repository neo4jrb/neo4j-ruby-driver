# frozen_string_literal: true

module TestkitBackend
  module Requests
    class ResultConsume < Data.define(:result_id)
      include Request

      def execute
        summary = registry.fetch(result_id).consume
        Response::Summary.new(SummaryPayload.new(summary: summary).to_h)
      end
    end
  end
end
