# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Whether the driver was constructed to enforce TLS. Implemented as
    # a real driver call — see Driver#encrypted? in
    # lib/mri/neo4j/driver/driver.rb (URI scheme + :encrypted option).
    class CheckDriverIsEncrypted < Data.define(:driver_id)
      include Request

      def execute
        Response::DriverIsEncrypted.new(encrypted: registry.fetch(driver_id).encrypted?)
      end
    end
  end
end
