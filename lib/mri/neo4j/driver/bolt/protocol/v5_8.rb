# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.8. Wire-identical to 5.7 from the client's perspective;
        # the version bump only flags additional server capabilities
        # negotiated through the manifest's capabilities bitmask.
        class V5_8 < V5_7
        end
      end
    end
  end
end
