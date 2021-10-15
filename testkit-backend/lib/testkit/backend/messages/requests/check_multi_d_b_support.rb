module Testkit::Backend::Messages
  module Requests
    class CheckMultiDBSupport < Request
      def process
        named_entity('MultiDBSupport', id: nil, available: fetch(driverId).supports_multi_db)
      end
    end
  end
end
