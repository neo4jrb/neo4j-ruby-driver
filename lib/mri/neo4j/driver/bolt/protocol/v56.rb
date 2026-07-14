# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.6. No client-visible wire change vs 5.5 — server-side
        # capability bump only (vector type availability on the server).
        class V56 < V55
        end
      end
    end
  end
end
