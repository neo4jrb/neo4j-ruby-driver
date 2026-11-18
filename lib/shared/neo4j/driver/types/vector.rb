# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # A Neo4j VECTOR value (Bolt 6.0+): a fixed-length sequence of numbers
      # sharing one element type — :int8, :int16, :int32, :int64, :float32 or
      # :float64 (Cypher's INTEGER8 … FLOAT64 vector coordinate types).
      # Mirrors the Java driver's Vector family (Int8Vector … Float64Vector)
      # as one value type shared by both flavours, the way Point and Duration
      # are.
      #
      #   vector = Neo4j::Driver::Types::Vector.new(:float32, [0.1, 0.2, 0.3])
      #   session.run('RETURN $v AS v', v: vector).single[:v] == vector # => true
      #   vector.to_a # => the elements as Ruby Floats (Integers for :int*)
      #
      # The elements are held in their big-endian wire encoding (`data`), so a
      # vector read from the server round-trips bit-exactly — including NaN
      # payloads a float32 -> Float -> float32 trip would not preserve — and a
      # large embedding costs one String rather than an Array of Floats.
      class Vector
        # Element type => [big-endian String#pack directive, byte width].
        ELEMENT_TYPES = {
          int8: ['c', 1],
          int16: ['s>', 2],
          int32: ['l>', 4],
          int64: ['q>', 8],
          float32: ['g', 4],
          float64: ['G', 8]
        }.freeze
        # Integer element type => the values it can hold. String#pack silently
        # truncates floats and wraps out-of-range integers (300 packs as 44 in
        # an int8 vector), so elements outside these are rejected rather than
        # sent to the server as a different number.
        INTEGER_RANGES = { int8: 8, int16: 16, int32: 32, int64: 64 }
                         .transform_values { -(2**(it - 1))..((2**(it - 1)) - 1) }.freeze
        # Canonical quiet-NaN wire bytes per float element type. The Java
        # driver is the reference for `==`, and its Vector#equals compares
        # Float/Double.floatToIntBits, which collapses every NaN bit-pattern to
        # one value — so two vectors that differ only in NaN payload are equal.
        # We mirror that by comparing NaN-canonicalised bytes (`canonical_data`)
        # while `data` keeps the exact payload for the wire. Signed zeros stay
        # distinct (different bits, not NaN), again matching Java.
        CANONICAL_NAN = { float32: [0x7fc00000].pack('L>'), float64: [0x7ff8000000000000].pack('Q>') }.freeze

        attr_reader :element_type, :data

        # Builds a vector from its raw big-endian element encoding, e.g. the
        # bytes of a VECTOR received from the server.
        def self.from_bytes(element_type, data) = allocate.tap { it.send(:assign, element_type, data.b) }

        def initialize(element_type, elements)
          directive, = layout(element_type)
          range = INTEGER_RANGES[element_type]
          invalid = range && elements.find_index { !(it.is_a?(Integer) && range.cover?(it)) }
          if invalid
            raise ArgumentError, "#{element_type} element #{elements[invalid].inspect} is not an Integer in #{range}"
          end

          assign(element_type, elements.pack("#{directive}*"))
        end

        def length = data.bytesize / layout(element_type).last
        alias size length

        def to_a = data.unpack("#{layout(element_type).first}*")

        def ==(other) = other.is_a?(self.class) && state == other.state
        alias eql? ==

        def hash = state.hash

        # Cypher literal form, after the Java driver's Vector#toString:
        # "vector([1, 2, 3], 3, INTEGER8 NOT NULL)". float32 elements print at
        # Ruby Float precision (0.1 as 0.10000000149011612).
        def to_s = "vector(#{to_a}, #{length}, #{element_type.to_s.upcase.sub('INT', 'INTEGER')} NOT NULL)"

        def inspect = "#<#{self.class.name} #{self}>"

        protected

        def state = [element_type, canonical_data]

        private

        # `data` with every NaN element replaced by the canonical quiet NaN, so
        # == and hash match the Java driver's floatToIntBits value-equality.
        # Integer vectors (and float vectors without a NaN) share the `data`
        # String unchanged — no scan, no copy.
        def canonical_data
          @canonical_data ||=
            if (canon = CANONICAL_NAN[element_type]) && (nans = nan_indexes).any?
              data.dup.tap { |bytes| nans.each { |i| bytes[i * canon.bytesize, canon.bytesize] = canon } }
            else
              data
            end
        end

        def nan_indexes
          directive, width = layout(element_type)
          (0...length).select { data[it * width, width].unpack1(directive).nan? }
        end

        def assign(element_type, data)
          width = layout(element_type).last
          size = data.bytesize
          unless (size % width).zero?
            raise ArgumentError, "#{element_type} vector data is #{size} bytes, not a multiple of #{width}"
          end

          @element_type = element_type
          @data = data
        end

        def layout(element_type)
          ELEMENT_TYPES.fetch(element_type) do
            raise ArgumentError, "Unknown vector element type #{element_type.inspect}, expected #{ELEMENT_TYPES.keys}"
          end
        end
      end
    end
  end
end
