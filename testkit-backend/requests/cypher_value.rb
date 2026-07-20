module TestkitBackend
  module Requests
    class CypherValue < Request
      def to_object
        value
      end
    end

    CypherBool = CypherNull = CypherInt = CypherString = CypherValue

    # UUID arrives as the canonical hyphenated string; wrap it in the
    # driver's flavor-agnostic type so the impl maps it to the wire.
    class CypherUUID < Request
      def to_object = Neo4j::Driver::Types::UUID.new(value)
    end
  end
end
