# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Builds a Ruby Date from a testkit CypherDate.
    class CypherDate < Request
      def to_object
        Date.new(year, month, day)
      end
    end
  end
end
