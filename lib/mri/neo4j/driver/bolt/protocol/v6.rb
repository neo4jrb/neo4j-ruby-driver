# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 6.0. HELLO / LOGON / TELEMETRY shapes are unchanged vs
        # 5.8; the major bump exists to (a) gate the manifest as the
        # only supported negotiation path and (b) introduce two new
        # server-pushed struct types in result records:
        #   - VECTOR     0x56 — packed numeric array; 2 fields
        #                       (element-type byte, raw bytes).
        #   - UNSUPPORTED 0x3F — forward-compat marker; 4 fields
        #                       (name, min_major, min_minor, extra).
        #
        # The driver has no public Types::Vector / Types::Unsupported
        # surface yet (Feature:API:Type.Vector is unimplemented), so we
        # surface them as plain hashes. The goal here is "don't crash
        # at hydration"; the proper type wrapping lands when there's a
        # public API to wire it to.
        class V6 < V58
          VECTOR_SIGNATURE = 0x56
          UNSUPPORTED_SIGNATURE = 0x3F

          def customize_hydration(unpacker)
            super
            unpacker.register_hydration_handler(VECTOR_SIGNATURE) do |fields|
              { element_type: fields[0], bytes: fields[1] }
            end
            unpacker.register_hydration_handler(UNSUPPORTED_SIGNATURE) do |fields|
              { name: fields[0], min_major: fields[1], min_minor: fields[2], extra: fields[3] }
            end
          end
        end
      end
    end
  end
end
