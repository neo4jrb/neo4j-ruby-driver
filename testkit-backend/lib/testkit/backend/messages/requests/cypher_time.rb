module Testkit::Backend::Messages
  module Requests
    class CypherTime < Request
      def to_object
        if utc_offset_s
          Neo4j::Driver::Types::OffsetTime.new(Time.new(1, 1, 1, hour, minute, second + nanosecond * 1e-9, utc_offset_s))
        else
          Neo4j::Driver::Types::LocalTime.new(Time.new(1, 1, 1, hour, minute, second + nanosecond * 1e-9))
        end
      end
    end
  end
end
