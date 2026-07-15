# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.0. HELLO shape is unchanged from V44 (auth still lives
        # inside HELLO; 5.1 is where it splits out). The visible delta is
        # on the wire: 5.0+ mandates UTC-seconds datetime encoding
        # (structures 0x49 / 0x69) for both pack and hydrate. The 0x46 /
        # 0x66 hydration handlers stay registered for back-compat reads
        # from older sources. Extends V44 so it keeps impersonation and
        # the ROUTE map form.
        class V5 < V44
          def configure_packer(packer)
            packer.use_utc_datetime = true
          end

          # 5.0+ makes UTC-seconds datetimes native, so drop the "utc" HELLO
          # patch V43 added — V43#hello_extra (inherited via V44) merges this
          # empty map, so 5.0 sends no patch_bolt.
          def patch_bolt_extra = {}
        end
      end
    end
  end
end
