# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Tries an auth token against the driver's connection.
    # Driver-side gap is documented in lib/mri/neo4j/driver/driver.rb
    # at #verify_authentication.
    class VerifyAuthentication < Data.define(:driver_id, :authorization_token)
      include Request

      def execute
        ok = registry.fetch(driver_id).verify_authentication(authorization_token)
        Response::DriverIsAuthenticated.new(id: driver_id, authenticated: ok)
      end
    end
  end
end
