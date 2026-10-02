# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Reports whether the referenced driver uses an encrypted connection.
    class CheckDriverIsEncrypted < Request
      def process
        named_entity('DriverIsEncrypted', encrypted: fetch(driver_id).encrypted?)
      end
    end
  end
end
