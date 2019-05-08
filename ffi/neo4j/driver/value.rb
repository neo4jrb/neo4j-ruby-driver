# frozen_string_literal: true

module Neo4j
  module Driver
    module Value
      SIGNATURES = {
        X: [Neo4j::Driver::Types::Point, 3],
        Y: [Neo4j::Driver::Types::Point, 4]
      }.freeze

      class << self
        private

        def rehash(&block)
          SIGNATURES.map { |code, klass_desc| [code.to_s.getbyte(0), klass_desc] }.map(&block).to_h.freeze
        end
      end

      CLASS = rehash { |code, (klass, _)| [code, klass] }
      SIZE = rehash { |code, (_, size)| [code, size] }
      CODE = rehash { |code, klass_desc| [klass_desc, code] }

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
              Array.new(Bolt::Value.size(value)) { |i| Bolt::Bytes.get(value, i) }
            )
          when :bolt_string
            Bolt::String.get(value).first
          when :bolt_dictionary
            Array.new(Bolt::Value.size(value)) do |i|
              [Bolt::Dictionary.get_key(value, i).first, to_ruby(Bolt::Dictionary.value(value, i))]
            end.to_h.symbolize_keys
          when :bolt_list
            Array.new(Bolt::Value.size(value)) { |i| to_ruby(Bolt::List.value(value, i)) }
          when :bolt_structure
            code = Bolt::Structure.code(value)
            handler = [Internal::DateValue, Internal::DurationValue, Internal::TimeWithZoneIdValue,
                       Internal::TimeWithZoneOffsetValue].find { |klass| klass.match(code) }
            return handler.to_ruby(value) if handler
            return unless CLASS[code]
            CLASS[code].send(
              :new,
              %i[srid x y z].zip(Array.new(SIZE[code]) { |i| to_ruby(Bolt::Structure.value(value, i)) }).to_h
            )
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
            Internal::DateValue.to_neo(value, object)
          when ActiveSupport::Duration
            Internal::DurationValue.to_neo(value, object)
          when Neo4j::Driver::Types::Point
            attributes = object.coordinates
            size = attributes.size + 1
            Bolt::Value.format_as_structure(value, CODE[[object.class, size]], size)
            to_neo(Bolt::Structure.value(value, 0), object.srid.to_i)
            attributes.each_with_index do |elem, index|
              to_neo(Bolt::Structure.value(value, index + 1), elem.to_f)
            end
            # when Neo4j::Driver::Types::OffsetTime
            #   Java::JavaTime::OffsetTime.of(object.hour, object.min, object.sec,
            #                                 object.nsec, Java::JavaTime::ZoneOffset.of_total_seconds(object.utc_offset))
            # when Neo4j::Driver::Types::LocalTime
            #   Java::JavaTime::LocalTime.of(object.hour, object.min, object.sec, object.nsec)
            # when Neo4j::Driver::Types::LocalDateTime
            #   Java::JavaTime::LocalDateTime.of(object.year, object.month, object.day, object.hour, object.min, object.sec,
            #                                    object.nsec)
          when ActiveSupport::TimeWithZone
            Internal::TimeWithZoneIdValue.to_neo(value, object)
          when Time
            Internal::TimeWithZoneOffsetValue.to_neo(value, object)
          else
            object
          end
        end
      end
    end
  end
end
