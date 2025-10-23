module Testkit::Backend::Messages
  module Requests
    class ResultNext < Request
      def process
        result = fetch(result_id)
        result.has_next? ? Responses::Record.new(result.next).to_testkit : named_entity('NullRecord')
      end
    end
  end
end