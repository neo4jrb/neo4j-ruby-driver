# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module NeoConverter
        private

        def to_neo(object, skip_unknown: false)
          case object
          when Hash
            object.map { |key, value| [key.to_s, to_neo(value)] }.to_h
          when Types::Path
            Exceptions::ClientException.unable_to_convert(object)
          when Enumerable
            object.map(&method(:to_neo))
          when String
            object.encoding == Encoding::BINARY ? object.to_java_bytes : object
          when ActiveSupport::Duration
            Java::OrgNeo4jDriverInternal::InternalIsoDuration.new(
              *Driver::Internal::DurationNormalizer.normalize(object)
            )
          when Types::Point
            Java::OrgNeo4jDriver::Values.point(object.srid, *object.coordinates)
          when Types::OffsetTime
            Java::JavaTime::OffsetTime.of(object.hour, object.min, object.sec,
                                          object.nsec, Java::JavaTime::ZoneOffset.of_total_seconds(object.utc_offset))
          when Types::LocalTime
            Java::JavaTime::LocalTime.of(object.hour, object.min, object.sec, object.nsec)
          when Types::LocalDateTime
            Java::JavaTime::LocalDateTime.of(object.year, object.month, object.day, object.hour, object.min, object.sec,
                                             object.nsec)
          when ActiveSupport::TimeWithZone
            to_zoned_date_time(object, object.time_zone.tzinfo.identifier)
          when Time, DateTime
            to_zoned_date_time(object, object.formatted_offset)
          when Date
            Java::JavaTime::LocalDate.of(object.year, object.month, object.day)
          when Symbol
            object.to_s
          when nil, true, false, Integer, Float
            object
          else
            if skip_unknown
              object
            else
              raise Exceptions::ClientException.unable_to_convert(object)
            end
          end
        end

        def to_zoned_date_time(object, zone)
          Java::JavaTime::ZonedDateTime.of(object.year, object.month, object.day, object.hour, object.min, object.sec,
                                           object.nsec, Java::JavaTime::ZoneId.of(zone))
        end
      end
    end
  end
end
