module Testkit::Backend::Messages
  module Requests
    class ResultPeek < Request
      def process
        result = fetch(result_id)
        result.has_next? ? named_entity('Record', values: result.peek.values.map(&method(:to_testkit))) : named_entity('NullRecord')
      end
    end
  end
end
