# frozen_string_literal: true

module TestkitBackend
  module Requests
    class CypherList < Request
      def to_object
        value.map(&Request.method(:object_from))
      end
    end
  end
end
