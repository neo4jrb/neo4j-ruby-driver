module Testkit::Backend::Messages
  module Requests
    class ForcedRoutingTableUpdate < Request
      def process
        named_entity('Driver', id: driver_id)
      end

      # def to_object
      # end
    end
  end
end
