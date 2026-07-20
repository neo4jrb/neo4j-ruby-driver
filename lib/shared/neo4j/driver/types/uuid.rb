# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # A Neo4j UUID value (Bolt 6.1+). Ruby has no stdlib UUID class, so
      # the driver owns this flavor-agnostic value type — just as Python's
      # driver surfaces the language-native `uuid.UUID`. Wraps the
      # canonical hyphenated string; each impl maps it to/from its own
      # native form (JRuby: java.util.UUID; MRI: the PackStream UUID
      # marker) at the wire boundary, never here.
      class UUID
        attr_reader :value

        def initialize(value)
          @value = value.to_s
        end

        def to_s = value

        def ==(other) = other.is_a?(UUID) && other.value == value
        alias eql? ==

        def hash = value.hash
      end
    end
  end
end
