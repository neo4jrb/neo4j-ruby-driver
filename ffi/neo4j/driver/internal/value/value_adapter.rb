# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Value
        module ValueAdapter
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
                Types::ByteArray.from_bytes(Array.new(Bolt::Value.size(value)) { |i| Bolt::Bytes.get(value, i) })
              when :bolt_string
                Bolt::String.get(value).first
              when :bolt_dictionary
                Array.new(Bolt::Value.size(value)) do |i|
                  [Bolt::Dictionary.get_key(value, i).first, to_ruby(Bolt::Dictionary.value(value, i))]
                end.to_h.symbolize_keys
              when :bolt_list
                Array.new(Bolt::Value.size(value)) { |i| to_ruby(Bolt::List.value(value, i)) }
              when :bolt_structure
                StructureValue.to_ruby(value)
              else
                raise Exception, 'unsupported neo4j type'
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
              when Array
                Bolt::Value.format_as_list(value, object.size)
                object.each_with_index { |elem, index| to_neo(Bolt::List.value(value, index), elem) }
              when Hash
                Bolt::Value.format_as_dictionary(value, object.size)
                object.each_with_index do |(key, elem), index|
                  key = key.to_s
                  Bolt::Dictionary.set_key(value, index, key, key.size)
                  to_neo(Bolt::Dictionary.value(value, index), elem)
                end
              when Date
                DateValue.to_neo(value, object)
              when ActiveSupport::Duration
                DurationValue.to_neo(value, object)
              when Neo4j::Driver::Types::Point
                case object.coordinates.size
                when 2
                  Point2DValue
                when 3
                  Point3DValue
                else
                  raise Exception
                end&.to_neo(value, object)
              when Types::OffsetTime
                OffsetTimeValue.to_neo(value, object)
              when Types::LocalTime
                LocalTimeValue.to_neo(value, object)
              when Types::LocalDateTime
                LocalDateTimeValue.to_neo(value, object)
              when ActiveSupport::TimeWithZone
                TimeWithZoneIdValue.to_neo(value, object)
              when Time
                TimeWithZoneOffsetValue.to_neo(value, object)
              else
                raise Exception, 'unsupported ruby type'
              end
              value
            end
          end
        end
      end
    end
  end
end
