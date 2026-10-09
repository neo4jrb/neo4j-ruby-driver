# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Builds a Ruby Hash by decoding each value of a testkit CypherMap.
    class CypherMap < Request
      def to_object
        value.transform_values(&Request.method(:object_from))
      end
    end
  end
end
