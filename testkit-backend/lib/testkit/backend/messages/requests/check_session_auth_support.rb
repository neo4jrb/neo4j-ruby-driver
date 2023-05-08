module Testkit::Backend::Messages
  module Requests
    class CheckSessionAuthSupport < Request
      def process
        named_entity('SessionAuthSupport', id: driver_id, available: fetch(driver_id).supports_session_auth?)
      end
    end
  end
end
