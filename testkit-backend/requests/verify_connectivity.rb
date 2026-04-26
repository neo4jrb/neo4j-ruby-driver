# frozen_string_literal: true

module TestkitBackend
  module Requests
    class VerifyConnectivity < Data.define(:driver_id)
      include Request

      def execute
        registry.fetch(driver_id).verify_connectivity
        Response::Driver.new(id: driver_id)
      end
    end
  end
end
