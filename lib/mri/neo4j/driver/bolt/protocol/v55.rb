# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.5. Server stops emitting the legacy `notifications`
        # list in SUCCESS metadata and switches to GQL status objects
        # (`statuses`). Hydration-side: ResultSummary#notifications
        # already falls back to `statuses` when the legacy key is
        # absent, so there's nothing version-specific to override here.
        class V55 < V54
        end
      end
    end
  end
end
