# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Builds a Ruby Array by decoding each element of a testkit CypherList.
    class CypherList < Request
      def to_object
        value.map(&Request.method(:object_from))
      end
    end
  end
end
