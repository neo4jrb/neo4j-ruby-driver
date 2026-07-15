# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 4.3. First version to offer the "utc" datetime patch
        # (HELLO `patch_bolt: ["utc"]`, opting into UTC-seconds encoding
        # 0x49/0x69). Otherwise identical to V4 — 4.2 does not support the
        # patch. V44 and every 5.x descend from here and inherit the
        # capability; V5 turns it back off since 5.0+ makes UTC native. The
        # packer only switches once the server confirms the patch in the
        # HELLO SUCCESS (Connection#perform_hello).
        class V43 < V4
          # Advertise the "utc" patch in HELLO. Inherited by V44 (and thus the
          # 5.x ladder); V5 resets patch_bolt_extra to {} since 5.0+ makes UTC
          # native. The packer only switches once the server confirms the patch
          # in the HELLO SUCCESS (Connection#perform_hello).
          def hello_extra(user_agent:, auth:, routing:)
            super.merge(patch_bolt_extra)
          end

          def patch_bolt_extra = { patch_bolt: ['utc'] }
        end
      end
    end
  end
end
