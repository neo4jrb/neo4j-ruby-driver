module Testkit::Backend::Messages
  module Requests
    class ResultConsume < Request
      def response = Responses::Summary.new(fetch(result_id).consume)
    end
  end
end
