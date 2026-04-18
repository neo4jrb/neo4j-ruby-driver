# frozen_string_literal: true

module Neo4j
  module Driver
    module PackStream
      # Represents a PackStream Structure with a signature and fields
      class Structure
        attr_reader :signature, :fields

        def initialize(signature, fields = [])
          @signature = signature
          @fields = fields
        end

        def ==(other)
          other.is_a?(Structure) &&
            other.signature == @signature &&
            other.fields == @fields
        end

        def to_s
          "Structure(0x#{@signature.to_s(16).upcase}, #{@fields.inspect})"
        end
      end
    end
  end
end
