# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Reports whether the referenced driver's server supports multiple databases.
    class CheckMultiDBSupport < Request
      def process
        named_entity('MultiDBSupport', id: driver_id, available: fetch(driver_id).supports_multi_db?)
      end
    end
  end
end
