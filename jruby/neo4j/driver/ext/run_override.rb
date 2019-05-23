# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module RunOverride
        include ExceptionCheckable

        # work around jruby issue https://github.com/jruby/jruby/issues/5603
        Struct.new('Wrapper', :object)

        def write_transaction
          super { |tx| Struct::Wrapper.new(yield(tx)) }.object
        end

        # end work around

        def run(statement, parameters = {})
          check { java_method(:run, [java.lang.String, java.util.Map]).call(statement, to_neo(parameters)) }
        end

        private

        def to_neo(object)
          case object
          when Hash
            object.map { |key, value| [key.to_s, to_neo(value)] }.to_h
          when Neo4j::Driver::Types::ByteArray
            object.to_java_bytes
          when Date
            Java::JavaTime::LocalDate.of(object.year, object.month, object.day)
          when ActiveSupport::Duration
            Java::OrgNeo4jDriverInternal::InternalIsoDuration.new(0, 0, object.to_i, 0)
          when Neo4j::Driver::Types::Point
            Java::OrgNeo4jDriverV1::Values.point(object.srid, *object.coordinates)
          when Neo4j::Driver::Types::OffsetTime
            Java::JavaTime::OffsetTime.of(object.hour, object.min, object.sec,
                                          object.nsec, Java::JavaTime::ZoneOffset.of_total_seconds(object.utc_offset))
          when Neo4j::Driver::Types::LocalTime
            Java::JavaTime::LocalTime.of(object.hour, object.min, object.sec, object.nsec)
          when Neo4j::Driver::Types::LocalDateTime
            Java::JavaTime::LocalDateTime.of(object.year, object.month, object.day, object.hour, object.min, object.sec,
                                             object.nsec)
          when ActiveSupport::TimeWithZone
            to_zoned_date_time(object, object.time_zone.tzinfo.identifier)
          when Time
            to_zoned_date_time(object, object.formatted_offset)
          else
            object
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
