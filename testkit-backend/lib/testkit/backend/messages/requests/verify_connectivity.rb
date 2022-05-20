module Testkit::Backend::Messages
  module Requests
    class VerifyConnectivity < Request
      def process
        fetch(driver_id).verify_connectivity
        named_entity('Driver', id: driver_id)
      end
    end
  end
end
