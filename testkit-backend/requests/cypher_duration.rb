# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Builds a driver Duration from a testkit CypherDuration.
    class CypherDuration < Request
      def to_object
        Neo4j::Driver::Types::Duration.new(months, days, seconds, nanoseconds)
      end
    end
  end
end
