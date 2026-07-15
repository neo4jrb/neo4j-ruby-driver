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
        #                       (name, min_major, min_minor, extra-map whose
        #                       optional `message` key carries a server note).
        #
        # UNSUPPORTED hydrates to Types::UnsupportedType (Feature:API:Type.
        # UnsupportedType). VECTOR stays a plain hash — Feature:API:Type.Vector
        # is unimplemented, so the goal there is still just "don't crash at
        # hydration" until there's a public API to wire it to.
        class V6 < V58
          VECTOR_SIGNATURE = 0x56
          UNSUPPORTED_SIGNATURE = 0x3F

          def customize_hydration(unpacker)
            super
            unpacker.register_hydration_handler(VECTOR_SIGNATURE) do |fields|
              { element_type: fields[0], bytes: fields[1] }
            end
            unpacker.register_hydration_handler(UNSUPPORTED_SIGNATURE) do |fields|
              # fields[3] is an extra map (symbol keys) whose :message is the
              # optional server note. Guard the type so a malformed/absent
              # 4th field can't crash hydration — the whole point of a
              # forward-compat marker is to survive the unexpected.
              extra = fields[3].is_a?(Hash) ? fields[3] : {}
              Types::UnsupportedType.new(fields[0], fields[1], fields[2], extra[:message])
            end
          end
        end
      end
    end
  end
end
