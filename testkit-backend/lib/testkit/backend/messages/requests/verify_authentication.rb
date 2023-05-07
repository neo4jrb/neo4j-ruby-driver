module Testkit::Backend::Messages
  module Requests
    class VerifyAuthentication < Request
      def process
        named_entity('DriverIsAuthenticated',
                     id: driver_id,
                     authenticated: fetch(driver_id).verify_authentication(Request.object_from(authorization_token)))
      end
    end
  end
end
