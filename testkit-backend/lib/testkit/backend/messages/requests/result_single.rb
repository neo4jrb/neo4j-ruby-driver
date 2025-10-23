module Testkit::Backend::Messages
  module Requests
    class ResultSingle < Request
      def response = Responses::Record.new(fetch(result_id).single)
    end
  end
end
