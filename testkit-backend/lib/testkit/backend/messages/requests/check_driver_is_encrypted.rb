module Testkit::Backend::Messages
  module Requests
    class CheckDriverIsEncrypted < Request
      def process
        named_entity('DriverIsEncrypted', encrypted: fetch(driver_id).encrypted?)
      end
    end
  end
end
