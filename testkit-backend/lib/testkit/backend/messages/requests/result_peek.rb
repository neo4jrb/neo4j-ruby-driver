module Testkit::Backend::Messages
  module Requests
    class ResultPeek < Request
      def process
        result = fetch(result_id)
        named_entity('Record', values: result.peek.values.map(&method(:to_testkit)))
      end
    end
  end
end
