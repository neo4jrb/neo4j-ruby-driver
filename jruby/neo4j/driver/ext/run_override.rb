# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module RunOverride
        include ExceptionCheckable
        extend AutoClosable

        auto_closable :begin_transaction

        # work around jruby issue https://github.com/jruby/jruby/issues/5603
        Struct.new('Wrapper', :object)

        %i[read write].each do |prefix|
          define_method("#{prefix}_transaction") do |&block|
            check { super { |tx| Struct::Wrapper.new(reverse_check { block.call(tx) }) }.object }
          end
        end

        # end work around

        def run(statement, parameters = {})
          Neo4j::Driver::Internal::Validator.require_hash_parameters!(parameters)
          check do
            java_method(:run, [org.neo4j.driver.v1.Statement])
              .call(Neo4j::Driver::Statement.new(statement, to_neo(parameters) || {}))
          end
        end

        def begin_transaction # (config = nil)
          check { super }
        end

        def close
          check { super }
        end

        private

        def to_neo(object)
          case object
          when Hash
            object.map { |key, value| [key.to_s, to_neo(value)] }.to_h
          when Types::Path
            Exceptions::ClientException.unable_to_convert(object)
          when Enumerable
            object.map(&method(:to_neo))
          when Types::Bytes
            object.to_java_bytes
          when Date
            Java::JavaTime::LocalDate.of(object.year, object.month, object.day)
          when ActiveSupport::Duration
            Java::OrgNeo4jDriverInternal::InternalIsoDuration.new(
              *Driver::Internal::DurationNormalizer.normalize(object)
            )
          when Types::Point
            Java::OrgNeo4jDriverV1::Values.point(object.srid, *object.coordinates)
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
          when Time
            to_zoned_date_time(object, object.formatted_offset)
          when nil, true, false, Integer, Float, String
            object
          else
            raise Exceptions::ClientException.unable_to_convert(object)
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
