# frozen_string_literal: true

module Neo4j
  module Driver
    module Value
      class << self
        def to_ruby(value)
          case Bolt::Value.type(value)
          when :bolt_null
            nil
          when :bolt_boolean
            Bolt::Boolean.get(value) == 1
          when :bolt_integer
            Bolt::Integer.get(value)
          when :bolt_float
            Bolt::Float.get(value)
          when :bolt_bytes
            Types::ByteArray.from_bytes(
              Array.new(Bolt::Value.size(value)) { |i| Bolt::Bytes.get(value, i) })
          when :bolt_string
            Bolt::String.get(value).first
          when :bolt_dictionary
            # Bolt::Dictionary.
          when :bolt_list
            # Bolt::List.
          when :bolt_structure
            Bolt::Structure.code(value)
          else
            to_string(value)
          end
        end

        def to_neo(value, object)
          case object
          when nil
            Bolt::Value.format_as_null(value)
          when TrueClass
            Bolt::Value.format_as_boolean(value, 1)
          when FalseClass
            Bolt::Value.format_as_boolean(value, 0)
          when Integer
            Bolt::Value.format_as_integer(value, object)
          when Float
            Bolt::Value.format_as_float(value, object)
          when Types::ByteArray
            Bolt::Value.format_as_bytes(value, object, object.size)
          when String
            Bolt::Value.format_as_string(value, object, object.size)
            # when Hash
            #   object.map { |key, value| [key.to_s, to_neo(value)] }.to_h
            # when Neo4j::Driver::Types::ByteArray
            #   object.to_java_bytes
            # when Date
            #   Java::JavaTime::LocalDate.of(object.year, object.month, object.day)
            # when ActiveSupport::Duration
            #   Java::OrgNeo4jDriverInternal::InternalIsoDuration.new(0, 0, object.to_i, 0)
            # when Neo4j::Driver::Types::Point
            #   Java::OrgNeo4jDriverV1::Values.point(object.srid, *object.coordinates)
            # when Neo4j::Driver::Types::OffsetTime
            #   Java::JavaTime::OffsetTime.of(object.hour, object.min, object.sec,
            #                                 object.nsec, Java::JavaTime::ZoneOffset.of_total_seconds(object.utc_offset))
            # when Neo4j::Driver::Types::LocalTime
            #   Java::JavaTime::LocalTime.of(object.hour, object.min, object.sec, object.nsec)
            # when Neo4j::Driver::Types::LocalDateTime
            #   Java::JavaTime::LocalDateTime.of(object.year, object.month, object.day, object.hour, object.min, object.sec,
            #                                    object.nsec)
            # when ActiveSupport::TimeWithZone
            #   to_zoned_date_time(object, object.time_zone.tzinfo.identifier)
            # when Time
            #   to_zoned_date_time(object, object.formatted_offset)
          else
            object
          end
        end
      end
    end
  end
end
