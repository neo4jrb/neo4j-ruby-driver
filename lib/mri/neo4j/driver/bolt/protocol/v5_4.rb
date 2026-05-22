# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.4. Adds the TELEMETRY request (signature 0x54). Driver
        # has no public API surface for it yet, so this class is a
        # version marker; the message tag lives in Bolt::Message for
        # whenever the API is added.
        class V5_4 < V5_3
        end
      end
    end
  end
end
