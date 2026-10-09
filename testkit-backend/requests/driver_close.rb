# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Closes the referenced driver and returns a Driver reference.
    class DriverClose < Request
      def process
        reference('Driver')
      end

      def to_object
        delete(driver_id).tap(&:close)
      end
    end
  end
end
