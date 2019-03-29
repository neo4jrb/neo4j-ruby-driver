# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module RunOverride
        # work around jruby issue https://github.com/jruby/jruby/issues/5603
        Struct.new('Wrapper', :object)

        def write_transaction
          super { |tx| Struct::Wrapper.new(yield(tx)) }.object
        end

        # end work around

        def run(statement, parameters = {})
          java_method(:run, [java.lang.String, java.util.Map]).call(statement, to_neo(parameters))
        rescue Java::OrgNeo4jDriverV1Exceptions::Neo4jException => e
          e.reraise
        end

        private

        def to_neo(object)
          if object.is_a? Hash
            object.map { |key, value| [key.to_s, to_neo(value)] }.to_h
          elsif object.is_a? Neo4j::Driver::ByteArray
            object.to_java_bytes
          elsif object.is_a? Date
            Java::JavaTime::LocalDate.of(object.year, object.month, object.day)
          elsif object.is_a? ActiveSupport::Duration
            Java::OrgNeo4jDriverInternal::InternalIsoDuration.new(0, 0, object.to_i, 0)
          elsif object.is_a? Neo4j::Driver::Point
            Java::OrgNeo4jDriverV1::Values.point(object.srid, *object.coordinates)
          elsif object.is_a? ActiveSupport::TimeWithZone
            to_zoned_date_time(object, object.time_zone.tzinfo.identifier)
          elsif object.is_a? Time
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
