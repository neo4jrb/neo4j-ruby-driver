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
        # VECTOR hydrates to (and Types::Vector packs as) the structure above
        # (Feature:API:Type.Vector); UNSUPPORTED hydrates to
        # Types::UnsupportedType (Feature:API:Type.UnsupportedType).
        class V6 < V58
          VECTOR_SIGNATURE = 0x56
          UNSUPPORTED_SIGNATURE = 0x3F
          # VECTOR element-type byte per Types::Vector element type — the
          # PackStream marker of the matching scalar (0xC6 is the otherwise
          # unused FLOAT_32 marker).
          VECTOR_TYPE_MARKERS = {
            int8: 0xC8, int16: 0xC9, int32: 0xCA, int64: 0xCB, float32: 0xC6, float64: 0xC1
          }.freeze

          def pack_vector(packer, value)
            packer.pack_vector_value(VECTOR_SIGNATURE, VECTOR_TYPE_MARKERS.fetch(value.element_type), value.data)
          end

          def customize_hydration(unpacker)
            super
            unpacker.register_hydration_handler(VECTOR_SIGNATURE) { hydrate_vector(*it) }
            unpacker.register_hydration_handler(UNSUPPORTED_SIGNATURE) do |fields|
              # fields[3] is an extra map (symbol keys) whose :message is the
              # optional server note. Guard the type so a malformed/absent
              # 4th field can't crash hydration — the whole point of a
              # forward-compat marker is to survive the unexpected.
              extra = fields[3].is_a?(Hash) ? fields[3] : {}
              Types::UnsupportedType.new(fields[0], fields[1], fields[2], extra[:message])
            end
          end

          private

          def hydrate_vector(type_marker, data)
            marker = type_marker.getbyte(0)
            element_type = VECTOR_TYPE_MARKERS.key(marker)
            unless element_type
              raise Exceptions::ProtocolException, format('Unknown VECTOR element type marker: 0x%02x', marker)
            end

            Types::Vector.from_bytes(element_type, data)
          end
        end
      end
    end
  end
end
