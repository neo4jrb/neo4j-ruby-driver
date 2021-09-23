module Testkit::Backend::Messages
  module Requests
    class VerifyConnectivity < Request
      def process
        fetch(driverId).verify_connectivity
        named_entity('Driver', id: driverId)
      end
    end
  end
end
