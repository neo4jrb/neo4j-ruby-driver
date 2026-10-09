# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Consumes the referenced result and returns its Summary.
    class ResultConsume < Request
      def response = Responses::Summary.new(fetch(result_id).consume)
    end
  end
end
