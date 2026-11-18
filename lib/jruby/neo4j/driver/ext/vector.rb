# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Adapts the Java driver's native Vector family (Int8Vector …
      # Float64Vector, all extending AbstractArrayVector) to the Ruby
      # Types::Vector surface. Prepended onto AbstractArrayVector, so a vector
      # read from the server is stored natively: no copy at hydration, == and
      # hash delegate to the Java value-equality (floatToIntBits, so differing
      # NaN payloads are equal and +0.0/-0.0 distinct), and to_a materialises
      # Ruby numbers only when asked.
      #
      # `data`/`from_bytes` bridge to the big-endian wire bytes on demand (for
      # the testkit backend and anything needing the raw payload); the elements
      # cross through a ByteBuffer view rather than Ruby numbers so a signalling
      # NaN's payload survives — widening a Java float to a Ruby Float would
      # quiet it.
      module Vector
        include Types::VectorContract

        # Types::Vector element type => [Java primitive class, ByteBuffer view, byte width].
        JAVA_TYPES = {
          int8: [Java::JavaLang::Byte::TYPE, :itself, 1],
          int16: [Java::JavaLang::Short::TYPE, :as_short_buffer, 2],
          int32: [Java::JavaLang::Integer::TYPE, :as_int_buffer, 4],
          int64: [Java::JavaLang::Long::TYPE, :as_long_buffer, 8],
          float32: [Java::JavaLang::Float::TYPE, :as_float_buffer, 4],
          float64: [Java::JavaLang::Double::TYPE, :as_double_buffer, 8]
        }.freeze

        # The native elementType() is a java.lang.Class; match it by value
        # (JRuby Class proxies aren't stable Hash keys, so a reverse Hash would
        # miss) to recover our symbol.
        def element_type = JAVA_TYPES.find { |_, (java_type, *)| java_type == elementType }.first

        def to_a = to_array.to_a

        def ==(other) = equals(other)
        alias eql? ==

        def hash = hashCode

        # The elements in their big-endian wire encoding, re-derived from the
        # native vector only when wanted.
        def data
          _, view, width = JAVA_TYPES.fetch(element_type)
          buffer = Java::JavaNio::ByteBuffer.allocate(length * width)
          buffer.public_send(view).put(to_array)
          String.from_java_bytes(buffer.array).force_encoding(Encoding::BINARY)
        end

        # Class-side helpers mirrored onto the Types::Vector alias (the Java
        # interface) so Types::Vector.new / .from_bytes build a native vector,
        # the same calls MRI's pure-Ruby class answers.
        module ClassMethods
          def new(element_type, elements)
            Types::VectorContract.validate_integer_elements(element_type, elements)
            elements_array = typed_array(element_type, elements.size)
            elements.each_with_index { |element, index| elements_array[index] = element }
            Java::OrgNeo4jDriver::Values.vector(elements_array).as_vector
          end

          def from_bytes(element_type, data)
            _, view, width = JAVA_TYPES.fetch(element_type) { unknown_type!(element_type) }
            Types::VectorContract.check_data_width(element_type, data.bytesize, width)
            elements_array = typed_array(element_type, data.bytesize / width)
            Java::JavaNio::ByteBuffer.wrap(data.b.to_java_bytes).public_send(view).get(elements_array)
            Java::OrgNeo4jDriver::Values.vector(elements_array).as_vector
          end

          private

          def typed_array(element_type, length)
            java_type, = JAVA_TYPES.fetch(element_type) { unknown_type!(element_type) }
            Java::JavaLangReflect::Array.new_instance(java_type, length)
          end

          def unknown_type!(element_type)
            Types::VectorContract.unknown_type!(element_type, JAVA_TYPES.keys)
          end
        end
      end
    end
  end
end
