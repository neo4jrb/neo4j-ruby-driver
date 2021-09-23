module Testkit::Backend::Messages
  module Requests
    class ResultConsume < Request
      def to_object
        fetch(resultId).consume
      end

      def response
        Responses::Summary.new(to_object)
      end
    end
  end
end
