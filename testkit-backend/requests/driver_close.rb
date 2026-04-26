# frozen_string_literal: true

module TestkitBackend
  module Requests
    class DriverClose < Data.define(:driver_id)
      include Request

      def execute
        registry.delete(driver_id)&.close
        Response::Driver.new(id: driver_id)
      end
    end
  end
end
