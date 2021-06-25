module Testkit::Backend::Messages
  module Requests
    class CypherMap < Request
      def to_object
        value.transform_values(&Request.method(:object_from))
      end
    end
  end
end