module TestkitBackend
  module Requests
    class ResultPeek < Request
      def process
        result = fetch(result_id)
        result.has_next? ? Responses::Record.new(result.peek).to_testkit : named_entity('NullRecord')
      end
    end
  end
end
