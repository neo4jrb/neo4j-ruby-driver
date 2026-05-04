# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 6.x protocol handler (inherits from V5)
        class V6 < V5
          def supports_re_auth?
            true
          end

          def supports_notification_filtering?
            true
          end
        end
      end
    end
  end
end
