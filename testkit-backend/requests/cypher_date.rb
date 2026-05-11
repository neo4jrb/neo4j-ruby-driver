module TestkitBackend
  module Requests
    class CypherDate < Request
      def to_object
        Date.new(year, month, day)
      end
    end
  end
end
