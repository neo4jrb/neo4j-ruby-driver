# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # A Neo4j UUID value (Bolt 6.1+). An opaque, immutable value type
      # mirroring java.util.UUID (which JRuby uses natively) and Python's
      # uuid.UUID — construct via `from_string`, read the canonical
      # hyphenated form via `to_s`. `new` is private so flavor-agnostic
      # code goes through `from_string`, the one constructor that also
      # exists on java.util.UUID.
      class UUID
        def self.from_string(value) = new(value)
        private_class_method :new

        def initialize(value)
          @value = value.to_s
        end

        def to_s = @value

        def ==(other) = other.is_a?(UUID) && other.to_s == @value
        alias eql? ==

        def hash = @value.hash
      end
    end
  end
end
