module TestkitBackend
  module Requests
    class CheckMultiDBSupport < Request
      def process
        named_entity('MultiDBSupport', id: driver_id, available: fetch(driver_id).supports_multi_db?)
      end
    end
  end
end
