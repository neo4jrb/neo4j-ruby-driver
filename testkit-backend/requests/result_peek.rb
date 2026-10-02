# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Returns the referenced result's next record without consuming it, or
    # NullRecord when exhausted.
    class ResultPeek < Request
      def process
        result = fetch(result_id)
        result.has_next? ? Responses::Record.new(result.peek).to_testkit : named_entity('NullRecord')
      end
    end
  end
end
