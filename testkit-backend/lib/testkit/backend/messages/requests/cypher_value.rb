module Testkit::Backend::Messages
  module Requests
    class CypherValue < Request
      def to_object
        value
      end
    end

    CypherBool = CypherNull = CypherInt = CypherFloat = CypherString = CypherValue
  end
end