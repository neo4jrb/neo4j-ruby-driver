# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.4. Adds the TELEMETRY request (signature 0x54).
        class V54 < V53
          def supports_telemetry? = true
        end
      end
    end
  end
end
