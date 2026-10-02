# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Returns the single record of the referenced result.
    class ResultSingle < Request
      def response = Responses::Record.new(fetch(result_id).single)
    end
  end
end
