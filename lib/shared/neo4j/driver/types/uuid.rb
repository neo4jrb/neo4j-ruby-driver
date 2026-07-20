# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # A Neo4j UUID value (Bolt 6.1+). A String subclass, so it behaves as
      # the canonical hyphenated string everywhere a string is expected,
      # while staying a distinct type the impls detect (before the plain
      # String case) to map onto the wire UUID form — JRuby: java.util.UUID;
      # MRI: the PackStream UUID marker. Ruby has no stdlib UUID class, so
      # the driver owns this, like Types::Point / Duration.
      class UUID < String
      end
    end
  end
end
