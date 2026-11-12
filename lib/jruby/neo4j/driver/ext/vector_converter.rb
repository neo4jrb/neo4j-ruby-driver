# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Converts between Types::Vector and the Java driver's Vector family
      # (Int8Vector … Float64Vector). The elements cross through a big-endian
      # ByteBuffer view rather than as Ruby numbers, so they keep their exact
      # bits — widening a Java float to a Ruby Float would quiet a signalling
      # NaN's payload.
      module VectorConverter
        # Types::Vector element type => [Java primitive class, ByteBuffer view].
        JAVA_TYPES = {
          int8: [Java::JavaLang::Byte::TYPE, :itself],
          int16: [Java::JavaLang::Short::TYPE, :as_short_buffer],
          int32: [Java::JavaLang::Integer::TYPE, :as_int_buffer],
          int64: [Java::JavaLang::Long::TYPE, :as_long_buffer],
          float32: [Java::JavaLang::Float::TYPE, :as_float_buffer],
          float64: [Java::JavaLang::Double::TYPE, :as_double_buffer]
        }.freeze

        module_function

        def to_ruby(vector)
          element_type, (_, view) = JAVA_TYPES.find { |_, (java_type, _)| java_type == vector.element_type }
          buffer = Java::JavaNio::ByteBuffer.allocate(vector.length * Types::Vector::ELEMENT_TYPES[element_type].last)
          buffer.public_send(view).put(vector.to_array)
          Types::Vector.from_bytes(element_type, String.from_java_bytes(buffer.array))
        end

        def to_java(vector)
          java_type, view = JAVA_TYPES.fetch(vector.element_type)
          elements = Java::JavaLangReflect::Array.new_instance(java_type, vector.length)
          Java::JavaNio::ByteBuffer.wrap(vector.data.to_java_bytes).public_send(view).get(elements)
          Java::OrgNeo4jDriver::Values.vector(elements).as_vector
        end
      end
    end
  end
end
