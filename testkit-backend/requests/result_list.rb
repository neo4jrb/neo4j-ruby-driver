# frozen_string_literal: true

module TestkitBackend
  module Requests
    class ResultList < Data.define(:result_id)
      include Request

      def execute
        records = registry.fetch(result_id).to_a.map do |record|
          record.values.map(&Cypher.method(:from_ruby))
        end
        Response::RecordList.new(records: records)
      end
    end
  end
end
