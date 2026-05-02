# frozen_string_literal: true

module TestkitBackend
  module Requests
    class CheckMultiDBSupport < Data.define(:driver_id)
      include Request

      def execute
        Response::MultiDBSupport.new(id: driver_id, available: registry.fetch(driver_id).supports_multi_db?)
      end
    end
  end
end
