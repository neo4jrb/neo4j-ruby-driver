# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # Behaviour the two flavours' Vector must share so they stay identical
      # where the public contract requires it: element validation, the
      # ArgumentError messages, and the Cypher-literal rendering. Each flavour
      # keeps its own storage — MRI the big-endian wire bytes, JRuby the native
      # Java Vector — but both include this so `new`, `==` error paths, `to_s`
      # and friends behave the same on either engine.
      module VectorContract
        # Integer element type => the values it can hold. Packing silently
        # wraps out-of-range integers (300 as 44 in an int8 vector), so elements
        # outside these are rejected rather than sent as a different number.
        INTEGER_RANGES = { int8: 8, int16: 16, int32: 32, int64: 64 }
                         .transform_values { -(2**(it - 1))..((2**(it - 1)) - 1) }.freeze

        # Rejects non-Integer or out-of-range elements of an integer vector
        # (a no-op for float vectors), with the same message on both flavours.
        def self.validate_integer_elements(element_type, elements)
          range = INTEGER_RANGES[element_type] or return
          invalid = elements.find_index { !(it.is_a?(Integer) && range.cover?(it)) }
          return unless invalid

          raise ArgumentError, "#{element_type} element #{elements[invalid].inspect} is not an Integer in #{range}"
        end

        def self.check_data_width(element_type, size, width)
          return if (size % width).zero?

          raise ArgumentError, "#{element_type} vector data is #{size} bytes, not a multiple of #{width}"
        end

        def self.unknown_type!(element_type, known)
          raise ArgumentError, "Unknown vector element type #{element_type.inspect}, expected #{known}"
        end

        def size = length

        # Cypher literal form, after the Java driver's Vector#toString:
        # "vector([1, 2, 3], 3, INTEGER8 NOT NULL)". float32 elements print at
        # Ruby Float precision (0.1 as 0.10000000149011612).
        def to_s = "vector(#{to_a}, #{length}, #{element_type.to_s.upcase.sub('INT', 'INTEGER')} NOT NULL)"

        # Hard-coded class name so the two flavours render identically — on
        # JRuby `self.class` is the Java impl (InternalFloat32Vector …).
        def inspect = "#<Neo4j::Driver::Types::Vector #{self}>"
      end
    end
  end
end
