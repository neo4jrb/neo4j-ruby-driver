module TestkitBackend
  module Requests
    class CypherTime < Request
      def to_object
        nanos = (hour * 3600 + minute * 60 + second) * 1_000_000_000 + nanosecond
        if utc_offset_s
          Neo4j::Driver::Types::OffsetTime.new(nanos, utc_offset_s)
        else
          Neo4j::Driver::Types::LocalTime.new(nanos)
        end
      end
    end
  end
end
