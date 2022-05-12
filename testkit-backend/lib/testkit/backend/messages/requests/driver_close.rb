module Testkit::Backend::Messages
  module Requests
    class DriverClose < Request
      def process
        reference('Driver')
      end

      def to_object
        delete(driver_id).tap(&:close)
      end
    end
  end
end