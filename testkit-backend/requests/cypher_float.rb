# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Builds a Ruby Float from a testkit CypherFloat, including NaN and ±Infinity.
    class CypherFloat < Request
      def to_object
        case value
        when 'NaN'
          Float::NAN
        when '-Infinity'
          -Float::INFINITY
        when '+Infinity'
          Float::INFINITY
        else
          value.to_f
        end
      end
    end
  end
end
