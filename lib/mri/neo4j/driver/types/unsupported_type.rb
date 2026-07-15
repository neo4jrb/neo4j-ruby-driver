# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # A value whose Bolt struct type is newer than this driver understands
      # (Bolt 6.0+ can push forward-compat markers, struct signature 0x3F). The
      # driver can't materialise the real value, but it must not crash — it
      # surfaces the type's name, the protocol version that introduced it, and
      # an optional server message so callers can react. Mirrors the Java
      # driver's UnsupportedType.
      class UnsupportedType
        attr_reader :name, :min_protocol_version, :message

        # `major`/`minor` are the wire ints (e.g. 6, 10); expose them joined as
        # "major.minor" the way testkit / the Java driver report it.
        def initialize(name, major, minor, message = nil)
          @name = name
          @min_protocol_version = "#{major}.#{minor}"
          @message = message
        end
      end
    end
  end
end
