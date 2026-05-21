# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Represents a Bolt protocol version
      class BoltVersion
        include Comparable

        attr_reader :major, :minor

        def initialize(major, minor = 0)
          @major = major
          @minor = minor
        end

        def to_i
          (@major << 8) | @minor
        end

        def to_s
          "#{@major}.#{@minor}"
        end

        # Comparable wires the rest (<, >, <=, >=, ==, between?, clamp)
        # off this one method.
        def <=>(other)
          to_i <=> other.to_i
        end

        # Known Bolt versions
        V3_0 = new(3, 0)
        V4_0 = new(4, 0)
        V4_1 = new(4, 1)
        V4_2 = new(4, 2)
        V4_3 = new(4, 3)
        V4_4 = new(4, 4)
        V5_0 = new(5, 0)
        V5_1 = new(5, 1)
        V5_2 = new(5, 2)
        V5_3 = new(5, 3)
        V5_4 = new(5, 4)
        V5_5 = new(5, 5)
        V5_6 = new(5, 6)
        V5_7 = new(5, 7)
        V6_0 = new(6, 0)

        # Server agreement is a 32-bit big-endian: [reserved, 0, minor, major].
        # So the low byte is major, the next-lowest is minor.
        def self.from_int(version_int)
          new(version_int & 0xFF, (version_int >> 8) & 0xFF)
        end
      end
    end
  end
end
