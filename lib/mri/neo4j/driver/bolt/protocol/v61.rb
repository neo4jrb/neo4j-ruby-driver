# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 6.1. HELLO / LOGON shapes are unchanged vs 6.0; the minor bump
        # introduces PackStream V2, whose only new type is UUID — a top-level
        # value (marker 0xE0 + 16 raw bytes), not a struct. This is the one
        # protocol version that supports it: pack/unpack the UUID codec here
        # instead of raising like Protocol::Base (Feature:API:Type.UUID,
        # Feature:Bolt:6.1).
        class V61 < V6
          def pack_uuid(packer, value) = packer.pack_uuid_value(value)

          def unpack_uuid(unpacker) = unpacker.unpack_uuid_value
        end
      end
    end
  end
end
