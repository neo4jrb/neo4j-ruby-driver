module Testkit::Backend::Messages
  module Requests
    class CypherValue < Request
      def to_object
        value
      end
    end

    CypherBool = CypherNull = CypherInt = CypherString = CypherValue
  end
end