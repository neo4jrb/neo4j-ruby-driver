module Testkit::Backend::Messages
  module Requests
    class CypherList < Request
      def to_object
        value.map(&Request.method(:object_from))
      end
    end
  end
end