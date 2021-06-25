module Testkit::Backend::Messages
  module Requests
    class ResultNext < Request
      def process
        result = fetch(resultId)
        result.has_next? ? named_entity('Record', values: result.next.values.map(&method(:to_testkit))) : named_entity('NullRecord')
      end
    end
  end
end