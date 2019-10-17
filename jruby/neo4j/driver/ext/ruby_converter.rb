# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module RubyConverter
        def as_ruby_object
          case type_constructor
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::LIST
            java_method(:asList, [org.neo4j.driver.v1.util.Function]).call(&:as_ruby_object).to_a
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::MAP
            as_map(->(x) { x.as_ruby_object }, nil).to_hash.symbolize_keys
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::DATE
            date = as_local_date
            Date.new(date.year, date.month_value, date.day_of_month)
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::DURATION
            ActiveSupport::Duration.parse(as_iso_duration.to_s)
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::POINT
            point = as_point
            Types::Point.new(srid: point.srid, x: point.x, y: point.y, z: nullable(point.z))
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::BYTES
            Types::Bytes.new(String.from_java_bytes(as_byte_array))
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::TIME
            Types::OffsetTime.parse(as_offset_time.to_string)
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::LOCAL_TIME
            Types::LocalTime.parse(as_local_time.to_string)
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::LOCAL_DATE_TIME
            Types::LocalDateTime.parse(as_local_date_time.to_string)
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::DATE_TIME
            to_time
          else
            as_object
          end
        end

        private

        def to_time
          time = as_zoned_date_time
          zone_id = time.zone.id
          if /^Z|[+\-][0-9]{2}:[0-9]{2}$/.match?(zone_id)
            Time.parse(time.to_string)
          else
            instant = time.to_instant
            Time.at(instant.epoch_second, instant.nano, :nsec).in_time_zone(TZInfo::Timezone.get(zone_id))
          end
        end

        def nullable(double)
          double unless double == java.lang.Double::NaN
        end
      end
    end
  end
end
