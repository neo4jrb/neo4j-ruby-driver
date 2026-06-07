module TestkitBackend
  module Requests
    class CypherDuration < Request
      def to_object
        Neo4j::Driver::Types::Duration.new(months, days, seconds, nanoseconds)
      end
    end
  end
end
