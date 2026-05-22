# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.0. HELLO shape is unchanged from V4 (auth still lives
        # inside HELLO; 5.1 is where it splits out). The visible delta is
        # on the wire: 5.0+ mandates UTC-seconds datetime encoding
        # (structures 0x49 / 0x69) for both pack and hydrate. The 0x46 /
        # 0x66 hydration handlers stay registered for back-compat reads
        # from older sources.
        class V5_0 < V4
          def configure_packer(packer)
            packer.use_utc_datetime = true
          end
        end
      end
    end
  end
end
