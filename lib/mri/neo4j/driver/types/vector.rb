# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # A Neo4j VECTOR value (Bolt 6.0+): a fixed-length sequence of numbers
      # sharing one element type — :int8, :int16, :int32, :int64, :float32 or
      # :float64 (Cypher's INTEGER8 … FLOAT64 vector coordinate types).
      #
      # This is the MRI implementation; JRuby aliases Types::Vector to the Java
      # driver's native Vector and provides the same surface via Ext::Vector.
      # Both include Types::VectorContract so they validate and render
      # identically. Here the elements are held in their big-endian wire
      # encoding (`data`), so a vector read from the server round-trips
      # bit-exactly — including NaN payloads a float32 -> Float -> float32 trip
      # would not preserve — and a large embedding costs one String rather than
      # an Array of Floats.
      #
      #   vector = Neo4j::Driver::Types::Vector.new(:float32, [0.1, 0.2, 0.3])
      #   session.run('RETURN $v AS v', v: vector).single[:v] == vector # => true
      #   vector.to_a # => the elements as Ruby Floats (Integers for :int*)
      class Vector
        include VectorContract

        # Element type => [big-endian String#pack directive, byte width].
        ELEMENT_TYPES = {
          int8: ['c', 1],
          int16: ['s>', 2],
          int32: ['l>', 4],
          int64: ['q>', 8],
          float32: ['g', 4],
          float64: ['G', 8]
        }.freeze
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
          VectorContract.validate_integer_elements(element_type, elements)
          assign(element_type, elements.pack("#{directive}*"))
        end

        def length = data.bytesize / layout(element_type).last

        def to_a = data.unpack("#{layout(element_type).first}*")

        def ==(other) = other.is_a?(self.class) && state == other.state
        alias eql? ==

        def hash = state.hash

        protected

        def state = [element_type, @canonical_data]

        private

        # `data` with every NaN element replaced by the canonical quiet NaN, so
        # == and hash match the Java driver's floatToIntBits value-equality.
        # Integer vectors (and float vectors without a NaN) reuse the `data`
        # String unchanged — no copy. Computed once in `assign` (not lazily on
        # first compare) so a frozen vector stays hashable and `==`/`hash` can't
        # drift from a later-mutated `data`.
        def compute_canonical_data
          canon = CANONICAL_NAN[element_type]
          nans = canon && nan_indexes
          return data unless nans&.any?

          data.dup.tap { |bytes| nans.each { |i| bytes[i * canon.bytesize, canon.bytesize] = canon } }
        end

        def nan_indexes
          directive, width = layout(element_type)
          (0...length).select { data[it * width, width].unpack1(directive).nan? }
        end

        def assign(element_type, data)
          VectorContract.check_data_width(element_type, data.bytesize, layout(element_type).last)
          @element_type = element_type
          @data = data
          @canonical_data = compute_canonical_data
        end

        def layout(element_type)
          ELEMENT_TYPES.fetch(element_type) { VectorContract.unknown_type!(element_type, ELEMENT_TYPES.keys) }
        end
      end
    end
  end
end
