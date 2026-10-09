# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Verifies the referenced driver can reach its server and returns a Driver
    # reference.
    class VerifyConnectivity < Request
      def process
        fetch(driver_id).verify_connectivity
        named_entity('Driver', id: driver_id)
      end
    end
  end
end
