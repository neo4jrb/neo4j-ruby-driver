module TestkitBackend
  module Requests
    class CypherValue < Request
      def to_object
        value
      end
    end

    CypherBool = CypherNull = CypherInt = CypherString = CypherValue

    # UUID arrives as the canonical hyphenated string; build the driver's
    # flavor-agnostic UUID (java.util.UUID on JRuby, Types::UUID on MRI) via
    # from_string, the constructor both share.
    class CypherUUID < Request
      def to_object = Neo4j::Driver::Types::UUID.from_string(value)
    end
  end
end
