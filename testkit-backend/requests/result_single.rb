# frozen_string_literal: true

module TestkitBackend
  module Requests
    class ResultSingle < Data.define(:result_id)
      include Request

      def execute
        Response::Record.from_driver_record(registry.fetch(result_id).single)
      end
    end
  end
end
