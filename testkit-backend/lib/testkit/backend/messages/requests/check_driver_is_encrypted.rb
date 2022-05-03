module Testkit::Backend::Messages
  module Requests
    class CheckDriverIsEncrypted < Request
      def process
        named_entity('DriverIsEncrypted', encrypted: fetch(driverId).is_encrypted?)
      end
    end
  end
end
