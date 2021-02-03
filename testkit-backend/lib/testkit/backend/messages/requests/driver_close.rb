module Testkit::Backend::Messages
  module Requests
    class DriverClose < Request
      def process
        reference('Driver')
      end

      def to_object
        delete(driverId).tap(&:close)
      end
    end
  end
end