module Testkit::Backend::Messages
  module Requests
    class ResultSingle < Request
      def process
        result = fetch(result_id)
        named_entity('Record', values: result.single.values.map(&method(:to_testkit)))
      end
    end
  end
end
