module TestkitBackend
  module Requests
    class CypherDuration < Request
      def to_object
        Neo4j::Driver::Internal::DurationNormalizer.create(months, days, seconds, nanoseconds)
      end
    end
  end
end
