module Testkit::Backend::Messages
  module Requests
    class CypherDateTime < Request
      def to_object
        if timezone_id
          Time.new(year, month, day, hour, minute, second + nanosecond * 1e-9, utc_offset_s).in_time_zone(TZInfo::Timezone.get(timezone_id))
        elsif utc_offset_s
          Time.new(year, month, day, hour, minute, second + nanosecond * 1e-9, utc_offset_s)
        else
          Neo4j::Driver::Types::LocalDateTime.new(Time.new(year, month, day, hour, minute, second + nanosecond * 1e-9))
        end
      end
    end
  end
end
